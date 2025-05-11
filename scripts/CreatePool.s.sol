// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "../src/HiveFactory.sol";

contract CreatePool is Script {
      address public hiveFactoryAddress = 0x3BbBc9332df75B956C549E176D78DC3852bFff3b;
      HiveFactory hiveFactory = HiveFactory(hiveFactoryAddress);
     
      function run() public {
        vm.startBroadcast();
        address btcToken = 0x876c1F2b47ecD167172E8Cc35Fcd5A6908A7e532;
        address idrxToken = 0x5475053c87CBbC301Fa16FD4FdD537321122dB17;
        address btc_usdc = hiveFactory.createHiveCore(btcToken, idrxToken);
        console.log("HiveCore BTC/IDRX deployed at:", btc_usdc);
        vm.stopBroadcast();
      }
}