// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../types/Types.sol";

interface IHiveCore {
    event OrderCreated(
        address indexed trader, uint256 indexed orderId, uint256 price, uint256 amount, OrderType orderType
    );
    event OrderCancelled(uint256 indexed orderId, address indexed trader);
    event OrderUpdated(uint256 indexed orderId, address indexed trader, uint256 newAmount);
    event OrderFilled(
        uint256 indexed orderId,
        address indexed trader,
        uint256 amount,
        uint256 filled,
        uint256 remaining,
        OrderType orderType
    );
    event TradeExecuted(address indexed buyer, address indexed seller, uint256 tradeAmount, uint256 price);

    function placeOrder(uint256[] memory price, uint256[] memory amount, OrderType orderType) external;
    function cancelOrder(uint256 id) external;
    function updateOrder(uint256 id, uint256 newAmount) external;
    function executeMarketOrder(
        uint256 amount,
        OrderType orderType,
        uint256[] memory prices,
        uint256 minAmount,
        uint256 expiration
    ) external;
    function getBaseToken() external view returns (address);
    function getQuoteToken() external view returns (address);
    function getLatestPrice() external view returns (uint256);
    function getOrder(uint256 id) external view returns (Order memory);
    function getUserOrderIds(address user) external view returns (uint256[] memory);
    function getBuyLiquidityAtPrice(uint256 price) external view returns (uint256);
    function getSellLiquidityAtPrice(uint256 price) external view returns (uint256);
}
