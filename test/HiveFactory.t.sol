// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/HiveFactory.sol";
import "../src/HiveCore.sol";
import "../src/library/TokenSort.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 tokens for testing
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
}

contract HiveFactoryTest is Test {
    HiveFactory public hiveFactory;
    MockERC20 public tokenA;
    MockERC20 public tokenB;
    MockERC20 public tokenC;

    address public alice = address(0x1);
    address public bob = address(0x2);

    // Event definition to match the one in HiveFactory
    event HiveCoreCreated(address indexed hiveCoreAddress, address indexed baseToken, address indexed quoteToken);

    function setUp() public {
        // Deploy mock tokens
        tokenA = new MockERC20("TokenA", "TA");
        tokenB = new MockERC20("TokenB", "TB");
        tokenC = new MockERC20("TokenC", "TC");

        address[] memory quoteTokens = new address[](1);
        console.log("TokenA address: %s", address(tokenA));
        console.log("TokenB address: %s", address(tokenB));
        console.log("TokenC address: %s", address(tokenC));
        quoteTokens[0] = address(tokenB);

        // Deploy HiveFactory
        hiveFactory = new HiveFactory(quoteTokens);

        // Fund Alice and Bob with tokens
        tokenA.transfer(alice, 1000 * 10 ** tokenA.decimals());
        tokenB.transfer(alice, 1000 * 10 ** tokenB.decimals());
        tokenA.transfer(bob, 1000 * 10 ** tokenA.decimals());
        tokenB.transfer(bob, 1000 * 10 ** tokenB.decimals());
    }

    // Test creating a new HiveCore pool
    function testCreateHiveCore() public {
        // Alice creates a new pool for tokenA (base) and tokenB (quote)
        vm.prank(alice);

        // Execute the transaction
        address hiveCoreAddress = hiveFactory.createHiveCore(address(tokenA), address(tokenB));

        // Verify that the pool was created
        assertTrue(hiveCoreAddress != address(0), "Pool address should not be zero");

        // Verify the pool is stored in the factory
        (address token0, address token1) = TokenSort.sortTokens(address(tokenA), address(tokenB));
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1));
        assertEq(hiveFactory.getHiveCore(poolId), hiveCoreAddress, "Pool address mismatch");
    }

    // Test creating a duplicate pool for the same tokens
    function testCreateDuplicateHiveCore() public {
        // Alice creates a new pool for tokenA and tokenB
        vm.prank(alice);
        hiveFactory.createHiveCore(address(tokenA), address(tokenB));

        // Attempt to create the same pool again (in reverse order)
        vm.prank(bob);
        vm.expectRevert("HiveFactory: POOL_ALREADY_EXISTS");
        hiveFactory.createHiveCore(address(tokenA), address(tokenB));
    }

    // Test creating a pool with identical tokens
    function testCreateHiveCoreWithIdenticalTokens() public {
        vm.prank(alice);
        vm.expectRevert("HiveFactory: IDENTICAL_TOKENS");
        hiveFactory.createHiveCore(address(tokenB), address(tokenB));
    }

    // Test creating a pool with zero address
    function testCreateHiveCoreWithZeroAddress() public {
        vm.prank(alice);
        vm.expectRevert("HiveFactory: INVALID_BASE_TOKEN");
        hiveFactory.createHiveCore(address(0), address(tokenB));
    }
}
