// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHiveFactory {
    event HiveCoreCreated(address indexed hiveCoreAddress, address indexed baseToken, address indexed quoteToken);
    event QuoteTokenAdded(address indexed quoteToken);

    function createHiveCore(address baseToken, address quoteToken) external returns (address);
    function getHiveCoreCount() external view returns (uint256);
    function getHiveCoreByIndex(uint256 index) external view returns (address);
    function getAllHiveCores() external view returns (address[] memory);
    function addQuoteToken(address quoteToken) external;
}
