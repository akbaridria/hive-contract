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
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Create 100 sell orders
        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, OrderType.SELL);
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
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        hive.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();
    }

    function testConcurrentTrading() public {
        uint256[] memory prices = new uint256[](1);
        uint256[] memory amounts = new uint256[](1);

        // Test rapid trading at the same price point
        prices[0] = 1000;
        amounts[0] = 1 * 10 ** 18;

        for (uint256 i = 0; i < 50; i++) {
            vm.startPrank(trader1);
            quoteToken.approve(address(hive), type(uint256).max);
            hive.placeOrder(prices, amounts, OrderType.BUY);
            vm.stopPrank();

            vm.startPrank(trader2);
            baseToken.approve(address(hive), type(uint256).max);
            hive.placeOrder(prices, amounts, OrderType.SELL);
            vm.stopPrank();
        }
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
        vm.expectRevert("HiveCore: BATCH_SIZE_TOO_LARGE");
        hive.placeOrder(prices, amounts, OrderType.BUY);
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
        console.log("balance quote trader1", quoteToken.balanceOf(trader1) / 1e18);
        console.log("amouts", amounts[0] / 1e18);
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        vm.startPrank(trader2);
        baseToken.approve(address(hive), type(uint256).max);
        console.log("balance base trader2", baseToken.balanceOf(trader2));
        console.log("amouts", amounts[0] / 1e18);
        hive.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        vm.startPrank(trader3);
        quoteToken.approve(address(hive), type(uint256).max);
        console.log("balance quote trader3", quoteToken.balanceOf(trader3));
        hive.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();
    }

    // Helper function to place a single order
    function placeOrderHelper(address trader, uint256 price, uint256 amount, OrderType orderType)
        internal
        returns (uint256 orderId)
    {
        vm.startPrank(trader);
        if (orderType == OrderType.BUY) {
            quoteToken.approve(address(hive), (price * amount) / (10 ** baseToken.decimals()));
        } else {
            baseToken.approve(address(hive), amount);
        }
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;
        hive.placeOrder(prices, amounts, orderType);
        vm.stopPrank();
        return hive.orderId(); // Assuming orderId is incremented after each order
    }

    // Test cancelOrder
    function testCancelOrder() public {
        // Place a buy order
        uint256 orderId = placeOrderHelper(trader1, 100, 10, OrderType.BUY);

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
        assertEq(trader1QuoteBalance, 100000 * 10 ** 18, "Trader1 should receive refund");

        // Verify the price is removed from the buyTree
        uint256[] memory buyPrices = hive.getBuyTreePrices();
        for (uint256 i = 0; i < buyPrices.length; i++) {
            assertEq(buyPrices[i], 0, "Buy tree should be 0 for every 20 elements");
        }
    }

    // Test updateOrder
    function testUpdateOrder() public {
        // Place a buy order
        uint256 orderId = placeOrderHelper(trader1, 100, 10, OrderType.BUY);

        // Update the order amount
        vm.prank(trader1);
        hive.updateOrder(orderId, 5);

        // Check updated order amount
        (,, uint256 amount,,,,,) = hive.orders(orderId);
        assertEq(amount, 5, "Order amount should be updated");

        // Check refund
        uint256 trader1QuoteBalance = quoteToken.balanceOf(trader1);
        assertEq(
            trader1QuoteBalance,
            100000 * 10 ** 18 - (100 * 5) / (10 ** baseToken.decimals()),
            "Trader1 should receive refund"
        );

        // Verify the price remains in the buyTree
        uint256[] memory buyPrices = hive.getBuyTreePrices();
        // assertEq(buyPrices.length, 1, "Buy tree should still contain the price");
        assertEq(buyPrices[0], 100, "Buy tree should contain the correct price");
    }

    // Test executeMarketOrder (Buy)
    function testExecuteBuyMarketOrder() public {
        // Place a sell order
        placeOrderHelper(trader1, 100, 10, OrderType.SELL);

        // Get initial balances
        uint256 initialTrader1QuoteBalance = quoteToken.balanceOf(trader1);
        uint256 initialTrader2BaseBalance = baseToken.balanceOf(trader2);
        uint256 initialTrader2QuoteBalance = quoteToken.balanceOf(trader2);

        // Execute a buy market order
        vm.startPrank(trader2);
        quoteToken.approve(address(hive), (100 * 10) / (10 ** baseToken.decimals()));
        hive.executeMarketOrder(10, OrderType.BUY);
        vm.stopPrank();

        // Check balances
        assertEq(baseToken.balanceOf(trader2), initialTrader2BaseBalance + 10, "Trader2 should receive 10 base tokens");
        assertEq(
            quoteToken.balanceOf(trader1),
            initialTrader1QuoteBalance + (100 * 10) / (10 ** baseToken.decimals()),
            "Trader1 should receive quote tokens for the sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader2),
            initialTrader2QuoteBalance - (100 * 10) / (10 ** baseToken.decimals()),
            "Trader2 should spend quote tokens for the buy order"
        );
    }

    // Test executeMarketOrder (Sell)
    function testExecuteSellMarketOrder() public {
        // Place a buy order
        placeOrderHelper(trader1, 100, 10, OrderType.BUY);

        // Get initial balances
        uint256 initialTrader1BaseBalance = baseToken.balanceOf(trader1);
        uint256 initialTrader2BaseBalance = baseToken.balanceOf(trader2);
        uint256 initialTrader2QuoteBalance = quoteToken.balanceOf(trader2);

        // Execute a sell market order
        vm.startPrank(trader2);
        baseToken.approve(address(hive), 10);
        hive.executeMarketOrder(10, OrderType.SELL);
        vm.stopPrank();

        // Check balances
        assertEq(
            quoteToken.balanceOf(trader2),
            initialTrader2QuoteBalance + (100 * 10) / (10 ** baseToken.decimals()),
            "Trader2 should receive quote tokens for the sell order"
        );
        assertEq(
            baseToken.balanceOf(trader1),
            initialTrader1BaseBalance + 10,
            "Trader1 should receive base tokens for the buy order"
        );
        assertEq(
            baseToken.balanceOf(trader2),
            initialTrader2BaseBalance - 10,
            "Trader2 should spend base tokens for the sell order"
        );
    }

    function testExecuteMarketOrderMultiplePriceLevels() public {
        // Place sell orders at multiple price levels
        placeOrderHelper(trader1, 100, 5, OrderType.SELL); // Price: 100, Amount: 5
        placeOrderHelper(trader2, 105, 3, OrderType.SELL); // Price: 105, Amount: 3
        placeOrderHelper(trader3, 110, 2, OrderType.SELL); // Price: 110, Amount: 2

        // Get initial balances
        uint256 initialTrader1QuoteBalance = quoteToken.balanceOf(trader1);
        uint256 initialTrader2QuoteBalance = quoteToken.balanceOf(trader2);
        uint256 initialTrader3QuoteBalance = quoteToken.balanceOf(trader3);
        uint256 initialBuyerBaseBalance = baseToken.balanceOf(trader3);
        uint256 initialBuyerQuoteBalance = quoteToken.balanceOf(trader3);

        // Execute a buy market order for 10 base tokens
        vm.startPrank(trader3);
        uint256 totalQuoteRequired = (100 * 5 + 105 * 3 + 110 * 2) / (10 ** baseToken.decimals());
        quoteToken.approve(address(hive), totalQuoteRequired);
        hive.executeMarketOrder(10, OrderType.BUY);
        vm.stopPrank();

        // Check balances
        assertEq(baseToken.balanceOf(trader3), initialBuyerBaseBalance + 10, "Buyer should receive 10 base tokens");
        assertEq(
            quoteToken.balanceOf(trader1),
            initialTrader1QuoteBalance + (100 * 5) / (10 ** baseToken.decimals()),
            "Trader1 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader2),
            initialTrader2QuoteBalance + (105 * 3) / (10 ** baseToken.decimals()),
            "Trader2 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader3),
            initialTrader3QuoteBalance + (110 * 2) / (10 ** baseToken.decimals()),
            "Trader3 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader3),
            initialBuyerQuoteBalance - totalQuoteRequired,
            "Buyer should spend the correct amount of quote tokens"
        );

        // Verify the sellTree is empty
        uint256[] memory sellPrices = hive.getSellTreePrices();
        // assertEq(sellPrices.length, 0, "Sell tree should be empty after filling all orders");
        for (uint256 i = 0; i < sellPrices.length; i++) {
            assertEq(sellPrices[i], 0, "Sell tree should be empty after filling all orders");
        }
    }

    function testExecuteMarketOrderWipeOutLiquidity() public {
        // Place sell orders
        placeOrderHelper(trader1, 100, 5, OrderType.SELL); // Price: 100, Amount: 5
        placeOrderHelper(trader2, 105, 3, OrderType.SELL); // Price: 105, Amount: 3

        // Get initial balances
        uint256 initialTrader1QuoteBalance = quoteToken.balanceOf(trader1);
        uint256 initialTrader2QuoteBalance = quoteToken.balanceOf(trader2);
        uint256 initialBuyerBaseBalance = baseToken.balanceOf(trader3);
        uint256 initialBuyerQuoteBalance = quoteToken.balanceOf(trader3);

        // Execute a buy market order for 10 base tokens (more than available liquidity)
        vm.startPrank(trader3);
        uint256 totalQuoteRequired = (100 * 5 + 105 * 3) / (10 ** baseToken.decimals());
        quoteToken.approve(address(hive), totalQuoteRequired);
        hive.executeMarketOrder(10, OrderType.BUY);
        vm.stopPrank();

        // Check balances
        assertEq(
            baseToken.balanceOf(trader3),
            initialBuyerBaseBalance + 8, // 5 + 3 = 8 base tokens filled
            "Buyer should receive 8 base tokens (partial fill)"
        );
        assertEq(
            quoteToken.balanceOf(trader1),
            initialTrader1QuoteBalance + (100 * 5) / (10 ** baseToken.decimals()),
            "Trader1 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader2),
            initialTrader2QuoteBalance + (105 * 3) / (10 ** baseToken.decimals()),
            "Trader2 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader3),
            initialBuyerQuoteBalance - (100 * 5 + 105 * 3) / (10 ** baseToken.decimals()),
            "Buyer should spend quote tokens for the partial fill"
        );

        // Verify the sellTree is empty
        uint256[] memory sellPrices = hive.getSellTreePrices();
        for (uint256 i = 0; i < sellPrices.length; i++) {
            assertEq(sellPrices[i], 0, "Sell tree should be empty after filling all orders");
        }
    }

    function testExecuteMarketOrderPartialFill() public {
        // Place sell orders
        placeOrderHelper(trader1, 100, 5, OrderType.SELL); // Price: 100, Amount: 5

        // Get initial balances
        uint256 initialTrader1QuoteBalance = quoteToken.balanceOf(trader1);
        uint256 initialBuyerBaseBalance = baseToken.balanceOf(trader2);
        uint256 initialBuyerQuoteBalance = quoteToken.balanceOf(trader2);

        // Execute a buy market order for 10 base tokens (more than available liquidity)
        vm.startPrank(trader2);
        uint256 totalQuoteRequired = (100 * 5) / (10 ** baseToken.decimals());
        quoteToken.approve(address(hive), totalQuoteRequired);
        hive.executeMarketOrder(10, OrderType.BUY);
        vm.stopPrank();

        // Check balances
        assertEq(
            baseToken.balanceOf(trader2),
            initialBuyerBaseBalance + 5,
            "Buyer should receive 5 base tokens (partial fill)"
        );
        assertEq(
            quoteToken.balanceOf(trader1),
            initialTrader1QuoteBalance + (100 * 5) / (10 ** baseToken.decimals()),
            "Trader1 should receive quote tokens for their sell order"
        );
        assertEq(
            quoteToken.balanceOf(trader2),
            initialBuyerQuoteBalance - (100 * 5) / (10 ** baseToken.decimals()),
            "Buyer should spend quote tokens for the partial fill"
        );

        // Verify the sellTree is empty
        uint256[] memory sellPrices = hive.getSellTreePrices();
        for (uint256 i = 0; i < sellPrices.length; i++) {
            assertEq(sellPrices[i], 0, "Sell tree should be empty after filling all orders");
        }
    }
}
