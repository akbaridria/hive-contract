// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HiveCore.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing
contract MockToken is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** 18);
    }
}

contract HiveCoreTest is Test {
    HiveCore public hive;
    MockToken public baseToken;
    MockToken public quoteToken;
    address public trader1;
    address public trader2;
    address public trader3;

    function setUp() public {
        // Create mock tokens
        baseToken = new MockToken("Base Token", "BASE");
        quoteToken = new MockToken("Quote Token", "QUOTE");

        // Deploy HiveCore
        hive = new HiveCore(address(baseToken), address(quoteToken));

        // Setup test accounts
        trader1 = address(0x1);
        trader2 = address(0x2);
        trader3 = address(0x3);

        // Fund test accounts
        vm.startPrank(address(this));
        baseToken.transfer(trader1, 100000 * 10 ** 18);
        baseToken.transfer(trader2, 100000 * 10 ** 18);
        baseToken.transfer(trader3, 100000 * 10 ** 18);
        quoteToken.transfer(trader1, 100000 * 10 ** 18);
        quoteToken.transfer(trader2, 100000 * 10 ** 18);
        quoteToken.transfer(trader3, 100000 * 10 ** 18);
        vm.stopPrank();
    }

    function testMassOrderPlacement() public {
        uint256[] memory prices = new uint256[](100);
        uint256[] memory amounts = new uint256[](100);

        // Create 100 buy orders
        for (uint256 i = 0; i < 100; i++) {
            prices[i] = 1000 + i;
            amounts[i] = 1 * 10 ** 18;
        }

        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();

        // Create 100 sell orders
        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.SELL);
        vm.stopPrank();
    }

    function testRandomizedOrderPlacement() public {
        uint256[] memory prices = new uint256[](50);
        uint256[] memory amounts = new uint256[](50);

        // Create random buy and sell orders
        for (uint256 i = 0; i < 50; i++) {
            prices[i] = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 2000 + 1000;
            amounts[i] = (uint256(keccak256(abi.encodePacked(block.timestamp, i + 50))) % 10 + 1) * 10 ** 18;
        }

        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();

        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.SELL);
        vm.stopPrank();
    }

    function testConcurrentTrading() public {
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        // Test rapid trading at the same price point
        prices[0] = 1000;
        amounts[0] = 1 * 10 ** 18;

        for (uint256 i = 0; i < 50; i++) {
            vm.prank(trader1);
            quoteToken.approve(address(hive), amounts[0]);
            hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);

            vm.prank(trader2);
            baseToken.approve(address(hive), amounts[0]);
            hive.placeOrder(prices, amounts, HiveCore.OrderType.SELL);
        }
    }

    function testEdgeCases() public {
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        // Test with maximum possible values
        prices[0] = type(uint256).max;
        amounts[0] = 1;

        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();

        // Test with minimum values
        prices[0] = 1;
        amounts[0] = 1;

        vm.startPrank(trader2);
        baseToken.approve(address(hive), 1);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.SELL);
        vm.stopPrank();
    }

    function testBatchSizeLimit() public {
        uint256[] memory prices = new uint256[](101);
        uint256[] memory amounts = new uint256[](101);

        for (uint256 i = 0; i < 101; i++) {
            prices[i] = 1000 + i;
            amounts[i] = 1 * 10 ** 18;
        }

        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        vm.expectRevert("Batch size too large");
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();
    }

    function testMultipleTraderInteraction() public {
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        prices[0] = 1000;
        amounts[0] = 1 * 10 ** 18;
        
        
        console.log("address hive", address(hive));

        // Multiple traders interacting with the same price point
        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();

        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.SELL);
        vm.stopPrank();

        vm.startPrank(trader3);
        quoteToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, HiveCore.OrderType.BUY);
        vm.stopPrank();
    }
}
