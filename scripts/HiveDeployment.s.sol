// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/HiveFactory.sol";
import "../src/mock-tokens/MockERC20.sol";

contract HiveDeployment is Script {
    function run() public {
        vm.startBroadcast();

        MockERC20 btcToken  = new MockERC20(msg.sender, msg.sender, "BTC Token", "BTC", 8);
        console.log("BTC Token deployed at:", address(btcToken));
        MockERC20 dummyX = new MockERC20(msg.sender, msg.sender, "DummyX Token", "DUMX", 18);
        console.log("DummyX Token deployed at:", address(dummyX));
        MockERC20 dummyY = new MockERC20(msg.sender, msg.sender, "DummyY Token", "DUMY", 18);
        console.log("DummyY Token deployed at:", address(dummyY));
        MockERC20 idrxToken = new MockERC20(msg.sender, msg.sender, "IDRX", "IDRX", 2);
        console.log("IDRX Token deployed at:", address(idrxToken));
        
        address[] memory quoteTokens = new address[](1);
        quoteTokens[0] = address(idrxToken);
        HiveFactory hiveFactory = new HiveFactory(quoteTokens);
        console.log("HiveFactory deployed at:", address(hiveFactory));
        
        vm.stopBroadcast();
    }
}
