// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/HiveCore.sol";
import "../src/types/Types.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract HiveFlowTestEdu is Script {
    // Constants
    address private constant HIVE_CORE_ADDRESS = 0x8aaF54F2C894365204d4148bCD6719928aF38e1A;
    
    // State variables
    HiveCore private hiveCore;
    ERC20 private btcToken;
    ERC20 private idrxToken;
    uint256 private btcMultiplier;
    uint256 private idrxMultiplier;
    
    function run() public {
        vm.startBroadcast();
        
        // Initialize contracts and configurations
        setupEnvironment();
        
        // Create test orders
        createBuyOrders();
        createSellOrders();
        
        // Test market operations
        executeMarketOperations();
        
        vm.stopBroadcast();
    }
    
    function setupEnvironment() private {
        // Initialize contracts
        hiveCore = HiveCore(HIVE_CORE_ADDRESS);
        btcToken = ERC20(hiveCore.getBaseToken());
        idrxToken = ERC20(hiveCore.getQuoteToken());
        
        // Configure multipliers based on token decimals
        uint8 decimalBtc = btcToken.decimals();
        uint8 decimalIdrx = idrxToken.decimals();
        btcMultiplier = 10 ** decimalBtc;
        idrxMultiplier = 10 ** decimalIdrx;
        
        // Approve tokens for trading
        btcToken.approve(HIVE_CORE_ADDRESS, type(uint256).max);
        idrxToken.approve(HIVE_CORE_ADDRESS, type(uint256).max);
        
        // Log initial balances
        uint256 balanceBtc = btcToken.balanceOf(msg.sender);
        uint256 balanceIdrx = idrxToken.balanceOf(msg.sender);
        console.log("Trader address:", msg.sender);
        console.log("Initial BTC balance:", balanceBtc);
        console.log("Initial IDRX balance:", balanceIdrx);
        console.log("Environment setup complete");
    }
    
    function createBuyOrders() private {
        // Define buy order prices and amounts
        uint256[] memory prices = new uint256[](5);
        prices[0] = 10 * idrxMultiplier;
        prices[1] = 20 * idrxMultiplier;
        prices[2] = 30 * idrxMultiplier;
        prices[3] = 40 * idrxMultiplier;
        prices[4] = 50 * idrxMultiplier;
        
        uint256[] memory amounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = btcMultiplier;
        }
        
        // Place individual buy orders
        for (uint256 i = 0; i < prices.length; i++) {
            uint256[] memory singlePrice = new uint256[](1);
            uint256[] memory singleAmount = new uint256[](1);
            singlePrice[0] = prices[i];
            singleAmount[0] = amounts[i];
            hiveCore.placeOrder(singlePrice, singleAmount, OrderType.BUY);
        }
        
        console.log("Buy orders created successfully");
    }
    
    function createSellOrders() private {
        // Define sell order prices and amounts
        uint256[] memory prices = new uint256[](5);
        prices[0] = 50 * idrxMultiplier;
        prices[1] = 60 * idrxMultiplier;
        prices[2] = 70 * idrxMultiplier;
        prices[3] = 80 * idrxMultiplier;
        prices[4] = 40 * idrxMultiplier;
        
        uint256[] memory amounts = new uint256[](5);
        for (uint256 i = 0; i < 5; i++) {
            amounts[i] = btcMultiplier;
        }
        
        // Place individual sell orders
        for (uint256 i = 0; i < prices.length; i++) {
            uint256[] memory singlePrice = new uint256[](1);
            uint256[] memory singleAmount = new uint256[](1);
            singlePrice[0] = prices[i];
            singleAmount[0] = amounts[i];
            hiveCore.placeOrder(singlePrice, singleAmount, OrderType.SELL);
        }
        
        console.log("Sell orders created successfully");
    }
    
    function executeMarketOperations() private {
        // Check initial price
        uint256 initialPrice = hiveCore.getLatestPrice();
        console.log("Initial market price:", initialPrice / idrxMultiplier, "IDRX");
        
        // Execute market sell order
        console.log("Executing market sell order for 2 BTC...");
        hiveCore.executeMarketOrder(2 * btcMultiplier, OrderType.SELL);
        
        // Check updated price
        uint256 updatedPrice = hiveCore.getLatestPrice();
        console.log("Updated market price:", updatedPrice / idrxMultiplier, "IDRX");
    }
}