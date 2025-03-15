// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/HiveFactory.sol";
import "../src/MockERC20.sol";

contract CounterScript is Script {
    function run() public {
        vm.startBroadcast();
        
        HiveFactory hiveFactory = new HiveFactory();
        console.log("HiveFactory deployed at:", address(hiveFactory));

        // deploy mock erc20 for BTC, USDC, USDT AND ETH
        MockERC20  = new MockERC20(address(this), address(this), "Base Token", "BASE", 18);
        console.log("Base Token deployed at:", address(baseToken));
        
        vm.stopBroadcast();
    }
}
