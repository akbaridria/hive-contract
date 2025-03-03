// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LimitTree.sol";

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
    }

    address private immutable baseToken;
    address private immutable quoteToken;

    mapping(uint256 => Order) public orders;
    mapping(uint256 => uint256[]) public buyOrderAtPrices;
    mapping(uint256 => uint256[]) public sellOrderAtPrices;

    LimitTree private buyTree;
    LimitTree private sellTree;

    uint256 public orderId;

    event OrderCreated(address indexed trader, uint256 price, uint256 amount, OrderType orderType);

    constructor(address _baseToken, address _quoteToken) {
        baseToken = _baseToken;
        quoteToken = _quoteToken;
    }

    function generateOrderId(uint256 amount, address trader, uint price) private view returns (bytes32) {
        return keccak256(abi.encodePacked(amount, trader, price, block.timestamp));
    }

    /**
     * @dev crete a single limit order
     *     @param price The price of the order
     *     @param amount The amount of the order
     *     @param orderType The type of the order
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
            active: true
        });

        if (orderType == OrderType.BUY) {
            buyTree.insert(price);
        } else {
            sellTree.insert(price);
        }

        emit OrderCreated(msg.sender, price, amount, orderType);
    }
}
