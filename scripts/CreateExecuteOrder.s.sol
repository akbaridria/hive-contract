// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/HiveFactory.sol";
import "../src/types/Types.sol";

contract CreateExecuteOrder is Script {
    address hiveCore = 0x1234567890123456789012345678901234567890;
    uint256 amount = 1000;
    uint256 price = 2000;
    HiveCore hiveCoreContract = HiveCore(hiveCore);


    function run() public {
        vm.startBroadcast();
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        hiveCoreContract.executeMarketOrder(amount, OrderType.BUY, prices, 0, 0);
        vm.stopBroadcast();
    }
}