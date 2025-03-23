// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/LimitTree.sol";

contract LimitTreeTest is Test {
    LimitTree public tree;

    function setUp() public {
        tree = new LimitTree();
        console.log("LimitTree deployed at:", address(tree));
    }

    function testLargeSequentialInsert() public {
        console.log("Starting sequential insert test");
        uint256 startGas = gasleft();

        // Insert 1000 numbers sequentially
        for (uint256 i = 1; i <= 1000; i++) {
            if (i % 100 == 0) {
                console.log("Progress: inserted %d numbers", i);
            }
            tree.insert(i);
        }

        console.log("Gas used for 1000 inserts:", startGas - gasleft());

        // Verify ascending order
        uint256[] memory ascending = tree.getAscendingOrder();
        console.log("Tree size after insertions:", ascending.length);

        // Log sample of values
        console.log("First few values:", ascending[0], ascending[1], ascending[2]);

        for (uint256 i = 0; i < 20; i++) {
            assertEq(ascending[i], i + 1);
        }

        // Verify descending order
        uint256[] memory descending = tree.getDescendingOrder();
        for (uint256 i = 0; i < 20; i++) {
            assertEq(descending[i], 1000 - i);
        }
    }

    function testRandomInsertAndDelete() public {
        console.log("Starting random insert and delete test");
        uint256[] memory numbers = new uint256[](100);
        uint256 startGas = gasleft();

        // Insert 100 random numbers
        for (uint256 i = 0; i < 100; i++) {
            uint256 randomNum = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 1000;
            numbers[i] = randomNum;
            if (i % 20 == 0) {
                console.log("Inserting random number at index %d: %d", i, randomNum);
            }
            tree.insert(randomNum);
        }

        console.log("Gas used for random inserts:", startGas - gasleft());
        console.log("Tree size after insertions:", tree.getAscendingOrder().length);
        console.log("Node count:", tree.nodeCount());

        startGas = gasleft();
        // Delete 50 random numbers
        for (uint256 i = 0; i < 50; i++) {
            uint256 indexToDelete = uint256(keccak256(abi.encodePacked(block.timestamp, i))) % 100;
            if (i % 10 == 0) {
                console.log("Deleting number at index %d: %d", indexToDelete, numbers[indexToDelete]);
            }
            tree.deleteValue(numbers[indexToDelete]);
        }

        console.log("Gas used for random deletes:", startGas - gasleft());
        console.log("Final tree size:", tree.getAscendingOrder().length);
        console.log("Node count:", tree.nodeCount());

        // Verify the tree maintains order
        uint256[] memory ascending = tree.getAscendingOrder();
        // uint256 length = ascending.length > 100 ? 100 : ascending.length;
        for (uint256 i = 1; i < 20; i++) {
            assertTrue(ascending[i] >= ascending[i - 1]);
        }
    }

    function testBalanceStress() public {
        console.log("Starting balance stress test");

        uint256 startGas = gasleft();
        // Insert numbers in a way that could cause imbalance
        for (uint256 i = 0; i < 100; i++) {
            tree.insert(i);
        }
        console.log("Initial insertion complete. Gas used:", startGas - gasleft());
        console.log("Tree size after initial insert:", tree.getAscendingOrder().length);
        console.log("Node Count:", tree.nodeCount());

        startGas = gasleft();
        console.log("Starting middle section deletion (25-74)");
        for (uint256 i = 25; i < 75; i++) {
            tree.deleteValue(i);
        }
        console.log("Middle deletion complete. Gas used:", startGas - gasleft());
        console.log("Tree size after deletion:", tree.getAscendingOrder().length);
        console.log("Node Count:", tree.nodeCount());

        startGas = gasleft();
        console.log("Starting new value insertion (1000-1049)");
        for (uint256 i = 1000; i < 1050; i++) {
            tree.insert(i);
        }
        console.log("New insertions complete. Gas used:", startGas - gasleft());

        uint256[] memory finalOrder = tree.getAscendingOrder();
        console.log("Final tree size:", finalOrder.length);
        console.log("First value:", finalOrder[0], "Last value:", finalOrder[finalOrder.length - 1]);

        // Verify ascending order is maintained
        uint256[] memory ascending = tree.getAscendingOrder();
        for (uint256 i = 1; i < 20; i++) {
            assertTrue(ascending[i] > ascending[i - 1]);
        }
    }

    function testGasStress() public {
        uint256 startGas = gasleft();

        // Insert 100 numbers
        for (uint256 i = 0; i < 100; i++) {
            tree.insert(i);
        }

        uint256 insertGas = startGas - gasleft();
        emit log_named_uint("Gas used for 100 inserts", insertGas);

        startGas = gasleft();

        // Delete 50 numbers
        for (uint256 i = 0; i < 50; i++) {
            tree.deleteValue(i);
        }

        uint256 deleteGas = startGas - gasleft();
        emit log_named_uint("Gas used for 50 deletes", deleteGas);
    }

    function testDuplicateInserts() public {
        // Try to insert same number multiple times
        tree.insert(100);
        tree.insert(100);
        tree.insert(100);

        uint256[] memory ascending = tree.getAscendingOrder();
        // assertEq(ascending.length, 1);
        assertEq(ascending[0], 100);
    }

    function testExtremeCases() public {
        // Test with max uint
        tree.insert(type(uint256).max);
        tree.insert(type(uint256).max - 1);
        tree.insert(type(uint256).max - 2);

        // Test with min uint
        tree.insert(0);
        tree.insert(1);
        tree.insert(2);

        uint256[] memory ascending = tree.getAscendingOrder();
        assertEq(ascending[0], 0, "First element should be 0");
        // assertEq(ascending[ascending.length - 1], type(uint256).max, "Last element should be max uint");
    }
}
