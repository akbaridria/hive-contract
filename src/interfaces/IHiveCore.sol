// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../types/Types.sol";

interface IHiveCore {
    event OrderCreated(address indexed trader, uint256 price, uint256 amount, OrderType orderType);
    event OrderCancelled(uint256 indexed orderId);
    event OrderUpdated(uint256 indexed orderId, uint256 newAmount);

    function placeOrder(uint256[] memory price, uint256[] memory amount, OrderType orderType) external;
    function cancelOrder(uint256 id) external;
    function updateOrder(uint256 id, uint256 newAmount) external;
    function executeMarketOrder(uint256 amount, OrderType orderType) external;
    function getBuyTreePrices() external view returns (uint256[] memory);
    function getSellTreePrices() external view returns (uint256[] memory);
}
