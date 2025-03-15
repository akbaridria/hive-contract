// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

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
