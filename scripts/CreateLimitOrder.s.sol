// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import "../src/HiveFactory.sol";
import "../src/types/Types.sol";
import "../src/mock-tokens/MockERC20.sol";

contract CreateLimitOrder is Script {
    address hiveCore = 0x27b698e1dEf9887D891cfB31fB0904BA31BB9110;
    uint256 amount = 1 * 10**8;
    uint256 price = 1 * 10**5;
    HiveCore hiveCoreContract = HiveCore(hiveCore);
    MockERC20 idrxToken = MockERC20(0x5475053c87CBbC301Fa16FD4FdD537321122dB17);

    function run() public {
        vm.startBroadcast();
        uint256 amountIdrx = hiveCoreContract._calculateQuoteAmount(amount, price);
        idrxToken.approve(address(hiveCoreContract), amountIdrx);
        idrxToken.balanceOf(msg.sender);
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        hiveCoreContract.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopBroadcast();
    }
}