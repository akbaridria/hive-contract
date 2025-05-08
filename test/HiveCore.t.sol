// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HiveCore.sol";
import "../src/types/Types.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract HiveCoreTest is Test {
    HiveCore public hiveCore;
    MockERC20 public baseToken;
    MockERC20 public quoteToken;

    address public alice = address(0x1);
    address public bob = address(0x2);
    address public charlie = address(0x3);

    function setUp() public {
        baseToken = new MockERC20("Base Token", "BASE");
        quoteToken = new MockERC20("Quote Token", "QUOTE");

        hiveCore = new HiveCore(address(baseToken), address(quoteToken));

        // Distribute tokens to test users
        baseToken.mint(alice, 1000 * 10 ** baseToken.decimals());
        baseToken.mint(bob, 1000 * 10 ** baseToken.decimals());
        baseToken.mint(charlie, 1000 * 10 ** baseToken.decimals());

        quoteToken.mint(alice, 1000 * 10 ** quoteToken.decimals());
        quoteToken.mint(bob, 1000 * 10 ** quoteToken.decimals());
        quoteToken.mint(charlie, 1000 * 10 ** quoteToken.decimals());
    }

    function testInitialState() public view {
        assertEq(hiveCore.getBaseToken(), address(baseToken));
        assertEq(hiveCore.getQuoteToken(), address(quoteToken));
        assertEq(hiveCore.getLatestPrice(), 0);
        assertEq(hiveCore.MAX_BATCH_SIZE(), 100);
    }

    function testPlaceSingleBuyOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals(); // 1 BASE = 1 QUOTE
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Approve tokens
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(amount, price));
        vm.stopPrank();

        // Place order
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.startPrank(alice);
        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Check order was created
        uint256[] memory aliceOrders = hiveCore.getUserOrderIds(alice);
        assertEq(aliceOrders.length, 1);

        Order memory order = hiveCore.getOrder(aliceOrders[0]);
        assertEq(order.trader, alice);
        assertEq(order.price, price);
        assertEq(order.amount, amount);
        assertEq(order.filled, 0);
        assertEq(order.active, true);

        // Check liquidity at price level
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), amount);
        assertEq(hiveCore.getSellLiquidityAtPrice(price), 0);
    }

    function testPlaceSingleSellOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals(); // 1 BASE = 1 QUOTE
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Approve tokens
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);
        vm.stopPrank();

        // Place order
        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.startPrank(alice);
        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Check order was created
        uint256[] memory aliceOrders = hiveCore.getUserOrderIds(alice);
        assertEq(aliceOrders.length, 1);

        Order memory order = hiveCore.getOrder(aliceOrders[0]);
        assertEq(order.trader, alice);
        assertEq(order.price, price);
        assertEq(order.amount, amount);
        assertEq(order.filled, 0);
        assertEq(order.active, true);

        // Check liquidity at price level
        assertEq(hiveCore.getSellLiquidityAtPrice(price), amount);
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), 0);
    }

    function testMatchingOrders() public {
        uint256 price = 1 * 10 ** quoteToken.decimals(); // 1 BASE = 1 QUOTE
        uint256 amount = 10 * 10 ** baseToken.decimals();
        uint256 quoteAmount = hiveCore._calculateQuoteAmount(amount, price);

        // Alice places a buy order
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), quoteAmount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Bob places a matching sell order
        vm.startPrank(bob);
        baseToken.approve(address(hiveCore), amount);

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Check orders were matched
        Order memory aliceOrder = hiveCore.getOrder(1);
        Order memory bobOrder = hiveCore.getOrder(2);

        assertEq(aliceOrder.filled, amount);
        assertEq(aliceOrder.active, false);
        assertEq(bobOrder.filled, amount);
        assertEq(bobOrder.active, false);

        // Check latest price was updated
        assertEq(hiveCore.getLatestPrice(), price);

        // Check liquidity was cleared
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), 0);
        assertEq(hiveCore.getSellLiquidityAtPrice(price), 0);

        // Check token transfers
        assertEq(baseToken.balanceOf(alice), 1000 * 10 ** baseToken.decimals() + amount); // Alice received baseToken
        assertEq(quoteToken.balanceOf(alice), 1000 * 10 ** quoteToken.decimals() - quoteAmount); // Alice spent quoteToken
        assertEq(baseToken.balanceOf(bob), 1000 * 10 ** baseToken.decimals() - amount); // Bob spent baseToken
        assertEq(quoteToken.balanceOf(bob), 1000 * 10 ** quoteToken.decimals() + quoteAmount); // Bob received quoteToken
    }

    function testPartialMatchingOrders() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 buyAmount = 10 * 10 ** baseToken.decimals();
        uint256 sellAmount = 5 * 10 ** baseToken.decimals();

        // Alice places a buy order
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(buyAmount, price));

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = buyAmount;

        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Bob places a smaller sell order
        vm.startPrank(bob);
        baseToken.approve(address(hiveCore), sellAmount);

        amounts[0] = sellAmount;
        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Check orders were partially matched
        Order memory aliceOrder = hiveCore.getOrder(1);
        Order memory bobOrder = hiveCore.getOrder(2);

        assertEq(aliceOrder.filled, sellAmount);
        assertEq(aliceOrder.active, true);
        assertEq(bobOrder.filled, sellAmount);
        assertEq(bobOrder.active, false);

        // Check latest price was updated
        assertEq(hiveCore.getLatestPrice(), price);

        // Check remaining liquidity
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), buyAmount - sellAmount);
        assertEq(hiveCore.getSellLiquidityAtPrice(price), 0);
    }

    function testCancelBuyOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Check initial balances
        uint256 initialQuoteBalance = quoteToken.balanceOf(alice);

        // Alice places a buy order
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(amount, price));

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Cancel order
        vm.startPrank(alice);
        hiveCore.cancelOrder(1);
        vm.stopPrank();

        // Check order was cancelled
        Order memory order = hiveCore.getOrder(1);
        assertEq(order.active, false);

        // Check liquidity was removed
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), 0);

        // Check funds were returned
        assertEq(quoteToken.balanceOf(alice), initialQuoteBalance);
    }

    function testCancelSellOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Check initial balances
        uint256 initialBaseBalance = baseToken.balanceOf(alice);

        // Alice places a sell order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Cancel order
        vm.startPrank(alice);
        hiveCore.cancelOrder(1);
        vm.stopPrank();

        // Check order was cancelled
        Order memory order = hiveCore.getOrder(1);
        assertEq(order.active, false);

        // Check liquidity was removed
        assertEq(hiveCore.getSellLiquidityAtPrice(price), 0);

        // Check funds were returned
        assertEq(baseToken.balanceOf(alice), initialBaseBalance);
    }

    function testUpdateBuyOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 initialAmount = 10 * 10 ** baseToken.decimals();
        uint256 newAmount = 15 * 10 ** baseToken.decimals();

        // Alice places a buy order
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(initialAmount, price));

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = initialAmount;

        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Check initial liquidity
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), initialAmount);

        // Update order with more amount
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(newAmount - initialAmount, price));

        hiveCore.updateOrder(1, newAmount);
        vm.stopPrank();

        // Check order was updated
        Order memory order = hiveCore.getOrder(1);

        assertEq(order.amount, newAmount);
    }

    function testUpdateSellOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 initialAmount = 10 * 10 ** baseToken.decimals();
        uint256 newAmount = 5 * 10 ** baseToken.decimals();

        // Alice places a sell order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), initialAmount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = initialAmount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Check initial liquidity
        assertEq(hiveCore.getSellLiquidityAtPrice(price), initialAmount);

        // Update order with less amount
        vm.startPrank(alice);
        hiveCore.updateOrder(1, newAmount);
        vm.stopPrank();

        // Check order was updated
        Order memory order = hiveCore.getOrder(1);
        assertEq(order.amount, newAmount);

        // Check excess was returned
        assertEq(baseToken.balanceOf(alice), 1000 * 10 ** baseToken.decimals() - newAmount);
    }

    function testExecuteBuyMarketOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();
        uint256 marketOrderAmount = hiveCore._calculateQuoteAmount(amount, price);

        // Bob places a sell order
        vm.startPrank(bob);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Alice executes a buy market order
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), marketOrderAmount);

        uint256[] memory marketPrices = new uint256[](1);
        marketPrices[0] = price;

        hiveCore.executeMarketOrder(
            marketOrderAmount,
            OrderType.BUY,
            marketPrices,
            0, // minAmount
            0 // expiration
        );
        vm.stopPrank();

        // Check orders were matched
        Order memory bobOrder = hiveCore.getOrder(1);
        assertEq(bobOrder.filled, amount);
        assertEq(bobOrder.active, false);

        // Check token transfers
        assertEq(baseToken.balanceOf(alice), 1000 * 10 ** baseToken.decimals() + amount); // Alice received baseToken
        assertEq(quoteToken.balanceOf(alice), 1000 * 10 ** quoteToken.decimals() - marketOrderAmount); // Alice spent quoteToken
        assertEq(baseToken.balanceOf(bob), 1000 * 10 ** baseToken.decimals() - amount); // Bob sold baseToken
        assertEq(quoteToken.balanceOf(bob), 1000 * 10 ** quoteToken.decimals() + marketOrderAmount); // Bob received quoteToken
    }

    function testExecuteSellMarketOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Bob places a buy order
        vm.startPrank(bob);
        quoteToken.approve(address(hiveCore), hiveCore._calculateQuoteAmount(amount, price));

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Alice executes a sell market order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory marketPrices = new uint256[](1);
        marketPrices[0] = price;

        hiveCore.executeMarketOrder(
            amount,
            OrderType.SELL,
            marketPrices,
            0, // minAmount
            0 // expiration
        );
        vm.stopPrank();

        // Check orders were matched
        Order memory bobOrder = hiveCore.getOrder(1);
        assertEq(bobOrder.filled, amount);
        assertEq(bobOrder.active, false);

        // Check token transfers
        uint256 expectedQuote = hiveCore._calculateQuoteAmount(amount, price);
        assertEq(quoteToken.balanceOf(alice), 1000 * 10 ** quoteToken.decimals() + expectedQuote);
        assertEq(baseToken.balanceOf(bob), 1000 * 10 ** baseToken.decimals() + amount);
    }

    function testBatchOrders() public {
        uint256 batchSize = 5;
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amountPerOrder = 2 * 10 ** baseToken.decimals();

        // Prepare arrays
        uint256[] memory prices = new uint256[](batchSize);
        uint256[] memory amounts = new uint256[](batchSize);

        for (uint256 i = 0; i < batchSize; i++) {
            prices[i] = price;
            amounts[i] = amountPerOrder;
        }

        // Approve total amount
        uint256 totalQuote = hiveCore._calculateQuoteAmount(amountPerOrder * batchSize, price);
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), totalQuote);

        // Place batch buy orders
        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Check all orders were created
        uint256[] memory aliceOrders = hiveCore.getUserOrderIds(alice);
        assertEq(aliceOrders.length, batchSize);

        // Check liquidity
        assertEq(hiveCore.getBuyLiquidityAtPrice(price), amountPerOrder * batchSize);
    }

    function testCannotPlaceInvalidOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Test zero price
        uint256[] memory prices = new uint256[](1);
        prices[0] = 0;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        vm.startPrank(alice);
        vm.expectRevert("HiveCore: QUOTE_AMOUNT_TOO_SMALL");
        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Test zero amount
        prices[0] = price;
        amounts[0] = 0;

        vm.startPrank(alice);
        vm.expectRevert("HiveCore: QUOTE_AMOUNT_TOO_SMALL");
        hiveCore.placeOrder(prices, amounts, OrderType.BUY);
        vm.stopPrank();

        // Test invalid order type
        amounts[0] = amount;

        // vm.startPrank(alice);
        // vm.expectRevert("HiveCore: INVALID_ORDER_TYPE");
        // hiveCore.placeOrder(prices, amounts, 2); // Invalid type
        // vm.stopPrank();
    }

    function testCannotCancelOthersOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Alice places an order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Bob tries to cancel Alice's order
        vm.startPrank(bob);
        vm.expectRevert("HiveCore: UNAUTHORIZED");
        hiveCore.cancelOrder(1);
        vm.stopPrank();
    }

    function testCannotUpdateOthersOrder() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Alice places an order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Bob tries to update Alice's order
        vm.startPrank(bob);
        vm.expectRevert("HiveCore: UNAUTHORIZED");
        hiveCore.updateOrder(1, amount * 2);
        vm.stopPrank();
    }

    function testCannotUpdateToInvalidAmount() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Alice places an order
        vm.startPrank(alice);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Try to update to zero amount
        vm.startPrank(alice);
        vm.expectRevert("HiveCore: INVALID_AMOUNT");
        hiveCore.updateOrder(1, 0);
        vm.stopPrank();
    }

    function testMarketOrderWithMinAmountProtection() public {
        uint256 price = 1 * 10 ** quoteToken.decimals();
        uint256 amount = 10 * 10 ** baseToken.decimals();

        // Bob places a sell order
        vm.startPrank(bob);
        baseToken.approve(address(hiveCore), amount);

        uint256[] memory prices = new uint256[](1);
        prices[0] = price;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = amount;

        hiveCore.placeOrder(prices, amounts, OrderType.SELL);
        vm.stopPrank();

        // Alice executes a buy market order with high minAmount
        uint256 marketOrderAmount = hiveCore._calculateQuoteAmount(amount, price);
        vm.startPrank(alice);
        quoteToken.approve(address(hiveCore), marketOrderAmount);

        uint256[] memory marketPrices = new uint256[](1);
        marketPrices[0] = price;

        vm.expectRevert("HiveCore: INSUFFICIENT_BASE_RECEIVED");
        hiveCore.executeMarketOrder(
            marketOrderAmount,
            OrderType.BUY,
            marketPrices,
            amount + 1, // minAmount (more than available)
            0
        );
        vm.stopPrank();
    }
}
