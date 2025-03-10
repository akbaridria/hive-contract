// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LimitTree.sol";
import "forge-std/console.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
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

    ERC20 private immutable baseToken;
    ERC20 private immutable quoteToken;

    mapping(uint256 => Order) public orders;
    mapping(uint256 => uint256) public buyOrderAtPrices;
    mapping(uint256 => uint256) public sellOrderAtPrices;

    LimitTree private buyTree;
    LimitTree private sellTree;

    uint256 public orderId;

    event OrderCreated(address indexed trader, uint256 price, uint256 amount, OrderType orderType);
    event OrderCancelled(uint256 indexed orderId);
    event OrderUpdated(uint256 indexed orderId, uint256 newAmount);

    constructor(address _baseToken, address _quoteToken) {
        baseToken = ERC20(_baseToken);
        quoteToken = ERC20(_quoteToken);
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
        uint256 totalQuoteAmount;
        for (uint256 i = 0; i < price.length; i++) {
            if (orderType == OrderType.BUY) {
                totalQuoteAmount += (price[i] * amount[i]) / (10 ** baseToken.decimals());
            } else {
                totalAmount += amount[i];
            }
        }

        if (orderType == OrderType.BUY) {
            quoteToken.transferFrom(msg.sender, address(this), totalQuoteAmount);
        } else {
            baseToken.transferFrom(msg.sender, address(this), totalAmount);
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

        if (bestBid >= bestAsk) {
            // execute trade
            while (buyOrderAtPrices[bestBid] != 0 && sellOrderAtPrices[bestAsk] != 0) {
                uint256 buyOrderId = buyOrderAtPrices[bestBid];
                uint256 sellOrderId = sellOrderAtPrices[bestAsk];

                Order storage buyOrder = orders[buyOrderId];
                Order storage sellOrder = orders[sellOrderId];

                uint256 tradeAmount = Math.min(buyOrder.amount - buyOrder.filled, sellOrder.amount - sellOrder.filled);
                uint256 tradeValue = (tradeAmount * bestBid) / (10 ** baseToken.decimals());

                quoteToken.transfer(sellOrder.trader, tradeValue);
                baseToken.transfer(buyOrder.trader, tradeAmount);

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

    /**
     *  @dev Cancel an order
     *  @param id The ID of the order to cancel
     */
    function cancelOrder(uint256 id) public {
        require(orders[id].trader == msg.sender, "Only the trader can cancel the order");
        require(orders[id].active, "Order is already inactive");

        Order storage order = orders[id];
        order.active = false;

        uint256 price = order.price;
        if (order.orderType == OrderType.BUY) {
            buyOrderAtPrices[price] = order.next;
            if (buyOrderAtPrices[price] == 0) {
                buyTree.deleteValue(price);
            }
        } else {
            sellOrderAtPrices[price] = order.next;
            if (sellOrderAtPrices[price] == 0) {
                sellTree.deleteValue(price);
            }
        }

        // Refund the remaining amount
        if (order.orderType == OrderType.BUY) {
            uint256 remainingAmount = (order.amount - order.filled) * order.price / (10 ** baseToken.decimals());
            quoteToken.transfer(msg.sender, remainingAmount);
        } else {
            uint256 remainingAmount = order.amount - order.filled;
            baseToken.transfer(msg.sender, remainingAmount);
        }

        emit OrderCancelled(id);
    }

    /**
     *  @dev Update the amount of an order
     *  @param id The ID of the order to update
     *  @param newAmount The new amount of the order
     */
    function updateOrder(uint256 id, uint256 newAmount) public {
        require(orders[id].trader == msg.sender, "Only the trader can update the order");
        require(orders[id].active, "Order is inactive");
        require(newAmount > 0, "Amount must be greater than 0");

        Order storage order = orders[id];

        // Ensure the new amount is not less than the filled amount
        require(newAmount > order.filled, "New amount must be greater than or equal to filled amount");

        // Calculate the difference in amount
        uint256 amountDifference;
        if (newAmount > order.amount) {
            amountDifference = newAmount - order.amount;
            // Transfer additional tokens from the trader
            if (order.orderType == OrderType.BUY) {
                uint256 additionalQuote = (amountDifference * order.price) / (10 ** baseToken.decimals());
                quoteToken.transferFrom(msg.sender, address(this), additionalQuote);
            } else {
                baseToken.transferFrom(msg.sender, address(this), amountDifference);
            }
        } else if (newAmount < order.amount) {
            amountDifference = order.amount - newAmount;
            // Refund excess tokens to the trader
            if (order.orderType == OrderType.BUY) {
                uint256 refundQuote = (amountDifference * order.price) / (10 ** baseToken.decimals());
                quoteToken.transfer(msg.sender, refundQuote);
            } else {
                baseToken.transfer(msg.sender, amountDifference);
            }
        }

        // Update the order amount
        order.amount = newAmount;

        emit OrderUpdated(id, newAmount);
    }

    /**
     * @dev Executes a market order.
     * @param amount The amount of the order.
     * @param orderType The type of the order (BUY or SELL).
     */
    function executeMarketOrder(uint256 amount, OrderType orderType) public {
        require(amount > 0, "Amount must be greater than 0");

        if (orderType == OrderType.BUY) {
            _executeBuyMarketOrder(amount);
        } else if (orderType == OrderType.SELL) {
            _executeSellMarketOrder(amount);
        } else {
            revert("Invalid order type");
        }
    }

    /**
     * @dev Executes a buy market order.
     * @param amount The amount of the order.
     */
    function _executeBuyMarketOrder(uint256 amount) private {
        uint256 remainingAmount = amount;
        uint256[] memory sellPrices = sellTree.getAscendingOrder();

        for (uint256 i = 0; i < sellPrices.length; i++) {
            uint256 price = sellPrices[i];
            uint256 sellOrderId = sellOrderAtPrices[price];

            while (sellOrderId != 0 && remainingAmount > 0) {
                Order storage sellOrder = orders[sellOrderId];

                uint256 tradeAmount = Math.min(sellOrder.amount - sellOrder.filled, remainingAmount);
                uint256 tradeValue = (tradeAmount * price) / (10 ** baseToken.decimals());

                // Transfer tokens
                quoteToken.transferFrom(msg.sender, sellOrder.trader, tradeValue);
                baseToken.transfer(msg.sender, tradeAmount);

                // Update order and remaining amount
                sellOrder.filled += tradeAmount;
                remainingAmount -= tradeAmount;

                // If the sell order is fully filled, deactivate it
                if (sellOrder.filled == sellOrder.amount) {
                    sellOrder.active = false;
                    sellOrderAtPrices[price] = sellOrder.next;
                }

                // Move to the next sell order at the same price
                sellOrderId = sellOrder.next;
            }

            // If no more sell orders at this price, remove the price from the sellTree
            if (sellOrderAtPrices[price] == 0) {
                sellTree.deleteValue(price);
            }

            // Stop if the market order is fully filled
            if (remainingAmount == 0) {
                break;
            }
        }
    }

    /**
     * @dev Executes a sell market order.
     * @param amount The amount of the order.
     */
    function _executeSellMarketOrder(uint256 amount) private {
        uint256 remainingAmount = amount;
        uint256[] memory buyPrices = buyTree.getDescendingOrder();

        for (uint256 i = 0; i < buyPrices.length; i++) {
            uint256 price = buyPrices[i];
            uint256 buyOrderId = buyOrderAtPrices[price];

            while (buyOrderId != 0 && remainingAmount > 0) {
                Order storage buyOrder = orders[buyOrderId];

                uint256 tradeAmount = Math.min(buyOrder.amount - buyOrder.filled, remainingAmount);
                uint256 tradeValue = (tradeAmount * price) / (10 ** baseToken.decimals());

                // Transfer tokens
                baseToken.transferFrom(msg.sender, buyOrder.trader, tradeAmount);
                quoteToken.transfer(msg.sender, tradeValue);

                // Update order and remaining amount
                buyOrder.filled += tradeAmount;
                remainingAmount -= tradeAmount;

                // If the buy order is fully filled, deactivate it
                if (buyOrder.filled == buyOrder.amount) {
                    buyOrder.active = false;
                    buyOrderAtPrices[price] = buyOrder.next;
                }

                // Move to the next buy order at the same price
                buyOrderId = buyOrder.next;
            }

            // If no more buy orders at this price, remove the price from the buyTree
            if (buyOrderAtPrices[price] == 0) {
                buyTree.deleteValue(price);
            }

            // Stop if the market order is fully filled
            if (remainingAmount == 0) {
                break;
            }
        }
    }

    /**
     *  @dev Get the buy tree prices
     *  @return The buy tree prices
     */
    function getBuyTreePrices() public view returns (uint256[] memory) {
        return buyTree.getAscendingOrder();
    }

    /**
     *  @dev Get the sell tree prices
     *  @return The sell tree prices
     */
    function getSellTreePrices() public view returns (uint256[] memory) {
        return sellTree.getDescendingOrder();
    }
}
