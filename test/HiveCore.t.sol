// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HiveCore.sol";
import "../src/types/Types.sol";
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
        baseToken.transfer(trader1, 1000 ether);
        baseToken.transfer(trader2, 1000 ether);
        baseToken.transfer(trader3, 1000 ether);
        quoteToken.transfer(trader1, 1000 ether);
        quoteToken.transfer(trader2, 1000 ether);
        quoteToken.transfer(trader3, 1000 ether);

        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        baseToken.approve(address(hive), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader2);
        quoteToken.approve(address(hive), type(uint256).max);
        baseToken.approve(address(hive), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(trader3);
        quoteToken.approve(address(hive), type(uint256).max);
        baseToken.approve(address(hive), type(uint256).max);
        vm.stopPrank();
    }

    function testFlow() public {
        console.log("Starting testFlow function");

        // test flow
        // place buy order at price 10, 20, 30, 40, 50 quote token
        // place sell order at price 50, 60, 70, 80, 40 base token

        uint8 decimalBase = baseToken.decimals();
        uint8 decimalQuote = quoteToken.decimals();
        uint256 baseMultiplier = 10 ** uint256(decimalBase);
        uint256 quoteMultiplier = 10 ** uint256(decimalQuote);

        console.log("Base token decimals:", decimalBase);
        console.log("Quote token decimals:", decimalQuote);
        console.log("Base multiplier:", baseMultiplier);
        console.log("Quote multiplier:", quoteMultiplier);

        // Log initial balances
        console.log("\n--- Initial Balances ---");
        console.log("Trader1 base token balance:", baseToken.balanceOf(trader1) / baseMultiplier);
        console.log("Trader1 quote token balance:", quoteToken.balanceOf(trader1) / quoteMultiplier);
        console.log("Trader2 base token balance:", baseToken.balanceOf(trader2) / baseMultiplier);
        console.log("Trader2 quote token balance:", quoteToken.balanceOf(trader2) / quoteMultiplier);
        console.log("Hive contract base token balance:", baseToken.balanceOf(address(hive)) / baseMultiplier);
        console.log("Hive contract quote token balance:", quoteToken.balanceOf(address(hive)) / quoteMultiplier);

        // Fixed price arrays with correct multiplier usage
        uint256[5] memory buyPrices = [
            uint256(10) * quoteMultiplier,
            uint256(20) * quoteMultiplier,
            uint256(30) * quoteMultiplier,
            uint256(40) * quoteMultiplier,
            uint256(50) * quoteMultiplier
        ];

        uint256[5] memory sellPrices = [
            uint256(50) * quoteMultiplier,
            uint256(60) * quoteMultiplier,
            uint256(70) * quoteMultiplier,
            uint256(80) * quoteMultiplier,
            uint256(40) * quoteMultiplier
        ];

        console.log("\n--- Placing BUY orders as trader1 ---");
        vm.startPrank(trader1);
        console.log("Address of trader1", address(trader1));
        for (uint256 i = 0; i < buyPrices.length; i++) {
            uint256[] memory prices = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);

            prices[0] = buyPrices[i];
            amounts[0] = baseMultiplier; // Amount in base token units

            console.log("Order amount:", amounts[0] / baseMultiplier, "base tokens");

            // Log balances before order
            console.log("  Before - Trader1 base:", baseToken.balanceOf(trader1) / baseMultiplier);
            console.log("  Before - Trader1 quote:", quoteToken.balanceOf(trader1) / quoteMultiplier);

            hive.placeOrder(prices, amounts, OrderType.BUY);

            // Log balances after order
            console.log("  After - Trader1 base:", baseToken.balanceOf(trader1) / baseMultiplier);
            console.log("  After - Trader1 quote:", quoteToken.balanceOf(trader1) / quoteMultiplier);
            console.log("  Hive base:", baseToken.balanceOf(address(hive)) / baseMultiplier);
            console.log("  Hive quote:", quoteToken.balanceOf(address(hive)) / quoteMultiplier);
        }
        vm.stopPrank();

        console.log("\n--- Placing SELL orders as trader2 ---");
        console.log("Address of trader2", address(trader2));
        vm.startPrank(trader2);
        for (uint256 i = 0; i < sellPrices.length; i++) {
            uint256[] memory prices = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);

            prices[0] = sellPrices[i];
            amounts[0] = baseMultiplier; // Amount in base token units

            console.log("Order amount:", amounts[0] / baseMultiplier, "base tokens");

            // Log balances before order
            console.log("  Before - Trader2 base:", baseToken.balanceOf(trader2) / baseMultiplier);
            console.log("  Before - Trader2 quote:", quoteToken.balanceOf(trader2) / quoteMultiplier);

            hive.placeOrder(prices, amounts, OrderType.SELL);

            // Log balances after order
            console.log("  After - Trader2 base:", baseToken.balanceOf(trader2) / baseMultiplier);
            console.log("  After - Trader2 quote:", quoteToken.balanceOf(trader2) / quoteMultiplier);
            console.log("  Hive base:", baseToken.balanceOf(address(hive)) / baseMultiplier);
            console.log("  Hive quote:", quoteToken.balanceOf(address(hive)) / quoteMultiplier);
        }
        vm.stopPrank();

        // Log final balances
        console.log("\n--- Final Balances ---");
        console.log("Trader1 base token balance:", baseToken.balanceOf(trader1) / baseMultiplier);
        console.log("Trader1 quote token balance:", quoteToken.balanceOf(trader1) / quoteMultiplier);
        console.log("Trader2 base token balance:", baseToken.balanceOf(trader2) / baseMultiplier);
        console.log("Trader2 quote token balance:", quoteToken.balanceOf(trader2) / quoteMultiplier);
        console.log("Hive contract base token balance:", baseToken.balanceOf(address(hive)) / baseMultiplier);
        console.log("Hive contract quote token balance:", quoteToken.balanceOf(address(hive)) / quoteMultiplier);

        uint256 latestPrice = hive.getLatestPrice();
        console.log("\nLatest price:", latestPrice / quoteMultiplier, "quote tokens");
        console.log("Expected price:", 40, "quote tokens");

        // Use assertEq from Foundry for better error messages
        assertEq(latestPrice, 40 * quoteMultiplier, "Latest price should be 40 * quoteMultiplier");

        console.log("testFlow completed successfully");
    }

    function testMassOrderPlacement() public {
        vm.startPrank(trader1);
        quoteToken.approve(address(hive), type(uint256).max);
        // Create 1000 buy orders
        for (uint256 i = 0; i < 1000; i++) {
            uint256[] memory prices = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            prices[0] = 1000 + i;
            amounts[0] = 1 * 10 ** 18;
            hive.placeOrder(prices, amounts, OrderType.BUY);
        }
        vm.stopPrank();

        // create 1000 sell orders
        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        for (uint256 i = 0; i < 1000; i++) {
            uint256[] memory prices = new uint256[](1);
            uint256[] memory amounts = new uint256[](1);
            prices[0] = 1000 + i;
            amounts[0] = 1 * 10 ** 18;
            hive.placeOrder(prices, amounts, OrderType.SELL);
        }
        vm.stopPrank();
    }

    function testCancelOrder() public {
        // Place a buy order
        vm.startPrank(trader1);
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        prices[0] = 100 * 10 ** quoteToken.decimals();
        amounts[0] = 10 * 10 ** baseToken.decimals();
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        uint256 orderId = 1;

        // Check order is active
        (,,,,,, bool active,) = hive.orders(orderId);
        assertTrue(active, "Order should be active");

        // Cancel the order
        vm.prank(trader1);
        hive.cancelOrder(orderId);

        // Check order is inactive
        (,,,,,, active,) = hive.orders(orderId);
        assertFalse(active, "Order should be inactive");

        // Check refund
        uint256 trader1QuoteBalance = quoteToken.balanceOf(trader1);
        assertEq(trader1QuoteBalance, 1000 * 10 ** 18, "Trader1 should receive refund");

        // Verify the price is removed from the buyTree
        uint256[] memory buyPrices = hive.getBuyTreePrices();
        for (uint256 i = 0; i < buyPrices.length; i++) {
            assertEq(buyPrices[i], 0, "Buy tree should be 0 for every 20 elements");
        }
    }

    // Test updateOrder
    function testUpdateOrder() public {
        // Place a buy order
        vm.startPrank(trader1);
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);
        prices[0] = 100 * 10 ** quoteToken.decimals();
        amounts[0] = 10 * 10 ** baseToken.decimals();
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        uint256 orderId = 1;

        // Update the order amount
        uint256 newAmount = 5 * 10 ** baseToken.decimals();
        vm.startPrank(trader1);
        hive.updateOrder(orderId, newAmount);
        vm.stopPrank();

        // Check updated order amount
        (,, uint256 amount,,,,,) = hive.orders(orderId);
        assertEq(amount, newAmount, "Order amount should be updated");

        // Check refund
        uint256 trader1QuoteBalance = quoteToken.balanceOf(trader1);
        assertEq(trader1QuoteBalance, 500 * 10 ** quoteToken.decimals(), "Trader1 should receive refund");

        // Verify the price remains in the buyTree
        uint256[] memory buyPrices = hive.getBuyTreePrices();
        // assertEq(buyPrices.length, 1, "Buy tree should still contain the price");
        assertEq(buyPrices[0], 100 * 10 ** quoteToken.decimals(), "Buy tree should contain the correct price");
    }
}
