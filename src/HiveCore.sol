// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LimitTree.sol";
import "forge-std/console.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract HiveCore {
    enum OrderType {
        BUY,
        SELL
    }

    struct Order {
        address trader;
        uint256 price;
        uint256 amount;
        uint256 filled;
        uint256 timestamp;
        OrderType orderType;
        bool active;
        uint256 next;
    }

    uint256 public constant MAX_BATCH_SIZE = 100;

    address private immutable baseToken;
    address private immutable quoteToken;

    mapping(uint256 => Order) public orders;
    mapping(uint256 => uint256) public buyOrderAtPrices;
    mapping(uint256 => uint256) public sellOrderAtPrices;

    LimitTree private buyTree;
    LimitTree private sellTree;

    uint256 public orderId;

    event OrderCreated(address indexed trader, uint256 price, uint256 amount, OrderType orderType);

    constructor(address _baseToken, address _quoteToken) {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
        buyTree = new LimitTree();
        sellTree = new LimitTree();
    }

    function generateOrderId(uint256 amount, address trader, uint256 price) private view returns (bytes32) {
        return keccak256(abi.encodePacked(amount, trader, price, block.timestamp));
    }

    /**
     *  @dev crete a single limit order
     *  @param price The price of the order
     *  @param amount The amount of the order
     *  @param orderType The type of the order
     */
    function _placeOrder(uint256 price, uint256 amount, OrderType orderType) internal {
        require(price > 0, "Price must be greater than 0");
        require(amount > 0, "Amount must be greater than 0");
        require(orderType == OrderType.BUY || orderType == OrderType.SELL, "Invalid order type");

        Order memory order = Order({
            trader: msg.sender,
            price: price,
            amount: amount,
            filled: 0,
            timestamp: block.timestamp,
            orderType: orderType,
            active: true,
            next: OrderType.BUY == orderType ? buyOrderAtPrices[price] : sellOrderAtPrices[price]
        });

        orderId++;
        orders[orderId] = order;

        if (orderType == OrderType.BUY) {
            buyTree.insert(price);
            buyOrderAtPrices[price] = orderId;
        } else {
            sellTree.insert(price);
            sellOrderAtPrices[price] = orderId;
        }

        emit OrderCreated(msg.sender, price, amount, orderType);
    }

    /**
     *  @dev Place multiple orders
     *  @param price The price of the order
     *  @param amount The amount of the order
     *  @param orderType The type of the order
     */
    function placeOrder(uint256[] memory price, uint256[] memory amount, OrderType orderType) public {
        require(price.length == amount.length, "Invalid input");
        require(price.length <= MAX_BATCH_SIZE, "Batch size too large");

        uint256 totalAmount;
        for (uint256 i = 0; i < price.length; i++) {
            totalAmount += amount[i];
        }

        if (orderType == OrderType.BUY) {
            IERC20(quoteToken).transferFrom(msg.sender, address(this), totalAmount);
        } else {
            IERC20(baseToken).transferFrom(msg.sender, address(this), totalAmount);
        }

        for (uint256 i = 0; i < price.length; i++) {
            _placeOrder(price[i], amount[i], orderType);
        }

        // match orders to executed trade if there's a match
        _matchOrder();
    }

    /**
     *  @dev Match orders to execute trade
     */
    function _matchOrder() internal {
        uint256[] memory listBids = buyTree.getAscendingOrder();
        uint256[] memory listAsks = sellTree.getDescendingOrder();

        if (listBids.length == 0 || listAsks.length == 0) {
            return;
        }

        uint256 bestBid = listBids[0];
        uint256 bestAsk = listAsks[0];

        if (bestBid == bestAsk) {
            // execute trade
            while (buyOrderAtPrices[bestBid] != 0 && sellOrderAtPrices[bestAsk] != 0) {
                uint256 buyOrderId = buyOrderAtPrices[bestBid];
                uint256 sellOrderId = sellOrderAtPrices[bestAsk];

                Order storage buyOrder = orders[buyOrderId];
                Order storage sellOrder = orders[sellOrderId];

                uint256 tradeAmount = Math.min(buyOrder.amount - buyOrder.filled, sellOrder.amount - sellOrder.filled);
                uint256 tradeValue = tradeAmount * bestBid;

                IERC20(quoteToken).transfer(buyOrder.trader, tradeValue);
                IERC20(baseToken).transfer(sellOrder.trader, tradeAmount);

                buyOrder.filled += tradeAmount;
                sellOrder.filled += tradeAmount;

                if (buyOrder.filled == buyOrder.amount) {
                    buyOrder.active = false;
                    buyOrderAtPrices[bestBid] = buyOrder.next;
                }

                if (sellOrder.filled == sellOrder.amount) {
                    sellOrder.active = false;
                    sellOrderAtPrices[bestAsk] = sellOrder.next;
                }
            }
            if (buyOrderAtPrices[bestBid] == 0) {
                buyTree.deleteValue(bestBid);
            }
            if (sellOrderAtPrices[bestAsk] == 0) {
                sellTree.deleteValue(bestAsk);
            }
        }
    }
}
