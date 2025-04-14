// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./LimitTree.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import "./interfaces/IHiveCore.sol";
import "./types/Types.sol";

contract HiveCore is IHiveCore {
    uint256 public constant MAX_BATCH_SIZE = 100;

    ERC20 private immutable baseToken;
    ERC20 private immutable quoteToken;

    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public userOrderIds;
    mapping(uint256 => PriceLevel) public buyOrderAtPrices;
    mapping(uint256 => PriceLevel) public sellOrderAtPrices;

    LimitTree private buyTree;
    LimitTree private sellTree;

    uint256 public orderId;
    uint256 public latestPrice; // Stores the most recent trade price

    constructor(address _baseToken, address _quoteToken) {
        baseToken = ERC20(_baseToken);
        quoteToken = ERC20(_quoteToken);
        buyTree = new LimitTree();
        sellTree = new LimitTree();
    }

    function generateOrderId(uint256 amount, address trader, uint256 price) private view returns (bytes32) {
        return keccak256(abi.encodePacked(amount, trader, price, block.timestamp));
    }

    /**
     *  @dev crete a single limit order
     *  @param price The price of the order
     *  @param amount The amount of the order
     *  @param orderType The type of the order
     */
    function _placeOrder(uint256 price, uint256 amount, OrderType orderType) internal {
        require(price > 0, "HiveCore: INVALID_PRICE");
        require(amount > 0, "HiveCore: INVALID_AMOUNT");
        require(orderType == OrderType.BUY || orderType == OrderType.SELL, "HiveCore: INVALID_ORDER_TYPE");

        Order memory order = Order({
            trader: msg.sender,
            price: price,
            amount: amount,
            filled: 0,
            timestamp: block.timestamp,
            orderType: orderType,
            active: true,
            next: orderType == OrderType.BUY ? buyOrderAtPrices[price].headOrderId : sellOrderAtPrices[price].headOrderId
        });

        orderId++;
        orders[orderId] = order;
        userOrderIds[msg.sender].push(orderId);

        if (orderType == OrderType.BUY) {
            buyTree.insert(price);
            buyOrderAtPrices[price].headOrderId = orderId;
            buyOrderAtPrices[price].totalLiquidity += amount;
            if (sellOrderAtPrices[price].headOrderId != 0) {
                _matchOrder(price);
            }
        } else {
            sellTree.insert(price);
            sellOrderAtPrices[price].headOrderId = orderId;
            sellOrderAtPrices[price].totalLiquidity += amount;
            if (buyOrderAtPrices[price].headOrderId != 0) {
                _matchOrder(price);
            }
        }

        emit OrderCreated(msg.sender, price, amount, orderType);
    }

    /**
     *  @dev Match orders to execute trade
     */
    function _matchOrder(uint256 price) internal {
        while (buyOrderAtPrices[price].headOrderId != 0 && sellOrderAtPrices[price].headOrderId != 0) {
            uint256 buyOrderId = buyOrderAtPrices[price].headOrderId;
            uint256 sellOrderId = sellOrderAtPrices[price].headOrderId;

            Order storage buyOrder = orders[buyOrderId];
            Order storage sellOrder = orders[sellOrderId];

            uint256 tradeAmount = Math.min(buyOrder.amount - buyOrder.filled, sellOrder.amount - sellOrder.filled);
            uint256 tradeValue = _calculateQuoteAmount(tradeAmount, price);

            quoteToken.transfer(sellOrder.trader, tradeValue);
            baseToken.transfer(buyOrder.trader, tradeAmount);

            // Update the latest price
            latestPrice = price;
            emit TradeExecuted(buyOrder.trader, sellOrder.trader, tradeAmount, latestPrice);

            // Update filled amounts
            buyOrder.filled += tradeAmount;
            sellOrder.filled += tradeAmount;

            // Update price level liquidity
            buyOrderAtPrices[price].totalLiquidity -= tradeAmount;
            sellOrderAtPrices[price].totalLiquidity -= tradeAmount;

            // If buy order is fully filled
            if (buyOrder.filled == buyOrder.amount) {
                buyOrder.active = false;
                buyOrderAtPrices[price].headOrderId = buyOrder.next;
            }

            // If sell order is fully filled
            if (sellOrder.filled == sellOrder.amount) {
                sellOrder.active = false;
                sellOrderAtPrices[price].headOrderId = sellOrder.next;
            }
        }

        // Remove price level if no more orders
        if (buyOrderAtPrices[price].headOrderId == 0) {
            buyTree.deleteValue(price);
            delete buyOrderAtPrices[price];
        }
        if (sellOrderAtPrices[price].headOrderId == 0) {
            sellTree.deleteValue(price);
            delete sellOrderAtPrices[price];
        }
    }

    /**
     *  @dev Place multiple orders
     *  @param price The price of the order
     *  @param amount The amount of the order
     *  @param orderType The type of the order
     */
    function placeOrder(uint256[] memory price, uint256[] memory amount, OrderType orderType) public override {
        require(price.length == amount.length, "HiveCore: INVALID_INPUT");
        require(price.length <= MAX_BATCH_SIZE, "HiveCore: BATCH_SIZE_TOO_LARGE");

        uint256 totalAmount;
        uint256 totalQuoteAmount;
        for (uint256 i = 0; i < price.length; i++) {
            if (orderType == OrderType.BUY) {
                totalQuoteAmount += _calculateQuoteAmount(amount[i], price[i]);
            } else {
                totalAmount += amount[i];
            }
        }

        if (orderType == OrderType.BUY) {
            quoteToken.transferFrom(msg.sender, address(this), totalQuoteAmount);
        } else {
            baseToken.transferFrom(msg.sender, address(this), totalAmount);
        }

        for (uint256 i = 0; i < price.length; i++) {
            _placeOrder(price[i], amount[i], orderType);
        }
    }

    /**
     *  @dev Cancel an order
     *  @param id The ID of the order to cancel
     */
    function cancelOrder(uint256 id) public override {
        require(orders[id].trader == msg.sender, "HiveCore: UNAUTHORIZED");
        require(orders[id].active, "HiveCore: ORDER_INACTIVE");

        Order storage order = orders[id];
        order.active = false;

        uint256 price = order.price;
        uint256 remainingAmount = order.amount - order.filled;

        if (order.orderType == OrderType.BUY) {
            // Update price level liquidity
            buyOrderAtPrices[price].totalLiquidity -= remainingAmount;

            // Update order chain
            if (buyOrderAtPrices[price].headOrderId == id) {
                buyOrderAtPrices[price].headOrderId = order.next;
            } else {
                // Need to find the previous order in the chain
                uint256 prevOrderId = buyOrderAtPrices[price].headOrderId;
                while (orders[prevOrderId].next != id) {
                    prevOrderId = orders[prevOrderId].next;
                }
                orders[prevOrderId].next = order.next;
            }

            // Remove price level if no more orders
            if (buyOrderAtPrices[price].headOrderId == 0) {
                buyTree.deleteValue(price);
                delete buyOrderAtPrices[price];
            }

            // Refund
            uint256 refundQuote = _calculateQuoteAmount(remainingAmount, price);
            quoteToken.transfer(msg.sender, refundQuote);
        } else {
            // Update price level liquidity
            sellOrderAtPrices[price].totalLiquidity -= remainingAmount;

            // Update order chain
            if (sellOrderAtPrices[price].headOrderId == id) {
                sellOrderAtPrices[price].headOrderId = order.next;
            } else {
                // Need to find the previous order in the chain
                uint256 prevOrderId = sellOrderAtPrices[price].headOrderId;
                while (orders[prevOrderId].next != id) {
                    prevOrderId = orders[prevOrderId].next;
                }
                orders[prevOrderId].next = order.next;
            }

            // Remove price level if no more orders
            if (sellOrderAtPrices[price].headOrderId == 0) {
                sellTree.deleteValue(price);
                delete sellOrderAtPrices[price];
            }

            // Refund
            baseToken.transfer(msg.sender, remainingAmount);
        }

        emit OrderCancelled(id);
    }

    /**
     *  @dev Update the amount of an order
     *  @param id The ID of the order to update
     *  @param newAmount The new amount of the order
     */
    function updateOrder(uint256 id, uint256 newAmount) public override {
        require(orders[id].trader == msg.sender, "HiveCore: UNAUTHORIZED");
        require(orders[id].active, "HiveCore: ORDER_INACTIVE");
        require(newAmount > 0, "HiveCore: INVALID_AMOUNT");

        Order storage order = orders[id];

        // Ensure the new amount is not less than the filled amount
        require(newAmount > order.filled, "HiveCore: AMOUNT_LESS_THAN_FILLED");

        // Calculate the difference in amount
        uint256 amountDifference;
        if (newAmount > order.amount) {
            amountDifference = newAmount - order.amount;
            // Transfer additional tokens from the trader
            if (order.orderType == OrderType.BUY) {
                uint256 additionalQuote = _calculateQuoteAmount(amountDifference, order.price);
                quoteToken.transferFrom(msg.sender, address(this), additionalQuote);
            } else {
                baseToken.transferFrom(msg.sender, address(this), amountDifference);
            }
        } else if (newAmount < order.amount) {
            amountDifference = order.amount - newAmount;
            // Refund excess tokens to the trader
            if (order.orderType == OrderType.BUY) {
                uint256 refundQuote = _calculateQuoteAmount(amountDifference, order.price);
                quoteToken.transfer(msg.sender, refundQuote);
            } else {
                baseToken.transfer(msg.sender, amountDifference);
            }
        }

        // Update the order amount
        order.amount = newAmount;

        emit OrderUpdated(id, newAmount);
    }

    /**
     * @dev Executes a market order.
     * @param amount For BUY orders: amount of quoteToken to spend buying baseToken.
     *               For SELL orders: amount of baseToken to sell for quoteToken.
     * @param orderType The type of the order (BUY or SELL).
     */
    function executeMarketOrder(uint256 amount, OrderType orderType) public override {
        require(amount > 0, "HiveCore: INVALID_AMOUNT");

        if (orderType == OrderType.BUY) {
            _executeBuyMarketOrder(amount);
        } else if (orderType == OrderType.SELL) {
            _executeSellMarketOrder(amount);
        } else {
            revert("Invalid order type");
        }
    }

    /**
     * @dev Executes a buy market order (amount in quoteToken).
     * @param quoteAmount The amount of quoteToken to spend.
     */
    function _executeBuyMarketOrder(uint256 quoteAmount) private {
        uint256 remainingQuote = quoteAmount;
        uint256[] memory sellPrices = sellTree.getAscendingOrder();

        // Transfer the full amount upfront (simpler accounting)
        quoteToken.transferFrom(msg.sender, address(this), quoteAmount);

        for (uint256 i = 0; i < sellPrices.length && remainingQuote > 0; i++) {
            uint256 price = sellPrices[i];
            uint256 sellOrderId = sellOrderAtPrices[price].headOrderId;

            while (sellOrderId != 0 && remainingQuote > 0) {
                Order storage sellOrder = orders[sellOrderId];
                uint256 availableBase = sellOrder.amount - sellOrder.filled;

                // Calculate maximum base token amount we can buy with remaining quote
                uint256 maxBaseForRemainingQuote = _calculateBaseAmount(remainingQuote, price);
                uint256 baseToTrade = Math.min(availableBase, maxBaseForRemainingQuote);

                // Calculate required quote token amount using the same precision logic
                uint256 quoteToSpend = _calculateQuoteAmount(baseToTrade, price);

                // Execute trade
                quoteToken.transfer(sellOrder.trader, quoteToSpend);
                baseToken.transfer(msg.sender, baseToTrade);

                // Update state
                latestPrice = price;
                emit TradeExecuted(msg.sender, sellOrder.trader, baseToTrade, latestPrice);

                sellOrder.filled += baseToTrade;
                sellOrderAtPrices[price].totalLiquidity -= baseToTrade;
                remainingQuote -= quoteToSpend;

                // Clean up filled orders
                if (sellOrder.filled == sellOrder.amount) {
                    sellOrder.active = false;
                    sellOrderAtPrices[price].headOrderId = sellOrder.next;
                }

                sellOrderId = sellOrder.next;
            }

            // Clean up empty price levels
            if (sellOrderAtPrices[price].headOrderId == 0) {
                sellTree.deleteValue(price);
                delete sellOrderAtPrices[price];
            }
        }

        // Return unused quote if any
        if (remainingQuote > 0) {
            quoteToken.transfer(msg.sender, remainingQuote);
        }
    }

    /**
     * @dev Executes a sell market order (amount in baseToken).
     * @param baseAmount The amount of baseToken to sell.
     */
    function _executeSellMarketOrder(uint256 baseAmount) private {
        uint256 remainingBase = baseAmount;
        uint256[] memory buyPrices = buyTree.getDescendingOrder();

        // Transfer the full amount upfront
        baseToken.transferFrom(msg.sender, address(this), baseAmount);

        for (uint256 i = 0; i < buyPrices.length && remainingBase > 0; i++) {
            uint256 price = buyPrices[i];
            uint256 buyOrderId = buyOrderAtPrices[price].headOrderId;

            while (buyOrderId != 0 && remainingBase > 0) {
                Order storage buyOrder = orders[buyOrderId];
                uint256 availableBase = buyOrder.amount - buyOrder.filled;
                uint256 baseToTrade = Math.min(availableBase, remainingBase);

                // Calculate quote tokens to receive using proper decimal handling
                uint256 quoteToReceive = _calculateQuoteAmount(baseToTrade, price);

                // Execute the trade
                baseToken.transfer(buyOrder.trader, baseToTrade);
                quoteToken.transfer(msg.sender, quoteToReceive);

                // Update state
                latestPrice = price;
                emit TradeExecuted(buyOrder.trader, msg.sender, baseToTrade, latestPrice);

                buyOrder.filled += baseToTrade;
                buyOrderAtPrices[price].totalLiquidity -= baseToTrade;
                remainingBase -= baseToTrade;

                // Clean up filled orders
                if (buyOrder.filled == buyOrder.amount) {
                    buyOrder.active = false;
                    buyOrderAtPrices[price].headOrderId = buyOrder.next;
                }

                buyOrderId = buyOrder.next;
            }

            // Clean up empty price levels
            if (buyOrderAtPrices[price].headOrderId == 0) {
                buyTree.deleteValue(price);
                delete buyOrderAtPrices[price];
            }
        }

        // Return unused base if any
        if (remainingBase > 0) {
            baseToken.transfer(msg.sender, remainingBase);
        }
    }

    /**
     * @param baseAmount Amount of baseToken (in baseToken's smallest units)
     * @param price Price of 1 baseToken in quoteToken's smallest units
     * @return quoteAmount Amount of quoteToken (in quoteToken's smallest units)
     */
    function _calculateQuoteAmount(uint256 baseAmount, uint256 price) internal view returns (uint256) {
        uint256 baseDecimals = baseToken.decimals();
        uint256 quoteAmount = (baseAmount * price) / (10 ** baseDecimals);

        // Protection against truncation to zero
        require(quoteAmount > 0, "HiveCore: QUOTE_AMOUNT_TOO_SMALL");
        return quoteAmount;
    }

    /**
     * @param quoteAmount Amount of quoteToken (in quoteToken's smallest units)
     * @param price Price of 1 baseToken in quoteToken's smallest units
     * @return baseAmount Amount of baseToken (in baseToken's smallest units)
     */
    function _calculateBaseAmount(uint256 quoteAmount, uint256 price) internal view returns (uint256) {
        uint256 baseDecimals = baseToken.decimals();
        uint256 baseAmount = (quoteAmount * (10 ** baseDecimals)) / price;

        // Protection against truncation to zero
        require(baseAmount > 0, "HiveCore: BASE_AMOUNT_TOO_SMALL");
        return baseAmount;
    }

    /**
     *  @dev Get the buy tree prices
     *  @return The buy tree prices
     */
    function getBuyTreePrices() public view override returns (uint256[] memory) {
        return buyTree.getAscendingOrder();
    }

    /**
     *  @dev Get the sell tree prices
     *  @return The sell tree prices
     */
    function getSellTreePrices() public view override returns (uint256[] memory) {
        return sellTree.getDescendingOrder();
    }

    /**
     * @dev get base token address
     * @return The address of the base token
     */
    function getBaseToken() public view override returns (address) {
        return address(baseToken);
    }

    /**
     * @dev get quote token address
     * @return The address of the quote token
     */
    function getQuoteToken() public view override returns (address) {
        return address(quoteToken);
    }

    /**
     * @dev get latest trade price
     * @return The latest trade price
     */
    function getLatestPrice() public view override returns (uint256) {
        return latestPrice;
    }

    /**
     * @dev get user order ids
     * @param user The address of the user
     * @return The order ids of the user
     */
    function getUserOrderIds(address user) external view override returns (uint256[] memory) {
        return userOrderIds[user];
    }

    /**
     * @dev get order details
     * @param id The id of the order
     * @return The order details
     */
    function getOrder(uint256 id) external view override returns (Order memory) {
        return orders[id];
    }

    /**
     *  @dev Get total liquidity at a buy price level
     *  @param price The price level to check
     *  @return The total liquidity at that price level
     */
    function getBuyLiquidityAtPrice(uint256 price) external view override returns (uint256) {
        return buyOrderAtPrices[price].totalLiquidity;
    }

    /**
     *  @dev Get total liquidity at a sell price level
     *  @param price The price level to check
     *  @return The total liquidity at that price level
     */
    function getSellLiquidityAtPrice(uint256 price) external view override returns (uint256) {
        return sellOrderAtPrices[price].totalLiquidity;
    }
}
