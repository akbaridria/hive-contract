// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract LimitTree {
    struct Node {
        uint256 value;
        uint256 height;
        bytes32 left;
        bytes32 right;
    }

    mapping(bytes32 => Node) public nodes;
    bytes32 public root;
    uint256 public nodeCount;

    // Generates a pseudorandom ID for nodes
    function generateNodeId(uint256 value, uint256 salt) private view returns (bytes32) {
        return keccak256(abi.encodePacked(value, salt, block.timestamp, msg.sender));
    }

    function insert(uint256 value) public {
        root = insertRecursive(root, value);
    }

    function insertRecursive(bytes32 nodeId, uint256 value) private returns (bytes32) {
        if (nodeId == bytes32(0)) {
            // Create new node with unique ID
            bytes32 newNodeId = generateNodeId(value, nodeCount);
            nodes[newNodeId] = Node(value, 1, bytes32(0), bytes32(0));
            nodeCount++;
            return newNodeId;
        }

        if (value < nodes[nodeId].value) {
            nodes[nodeId].left = insertRecursive(nodes[nodeId].left, value);
        } else if (value > nodes[nodeId].value) {
            nodes[nodeId].right = insertRecursive(nodes[nodeId].right, value);
        } else {
            return nodeId; // Duplicate values not allowed
        }

        nodes[nodeId].height = 1 + max(getHeight(nodes[nodeId].left), getHeight(nodes[nodeId].right));

        int256 balance = getBalance(nodeId);

        // Rotations
        if (balance > 1 && value < nodes[nodes[nodeId].left].value) {
            return rotateRight(nodeId);
        }
        if (balance < -1 && value > nodes[nodes[nodeId].right].value) {
            return rotateLeft(nodeId);
        }
        if (balance > 1 && value > nodes[nodes[nodeId].left].value) {
            nodes[nodeId].left = rotateLeft(nodes[nodeId].left);
            return rotateRight(nodeId);
        }
        if (balance < -1 && value < nodes[nodes[nodeId].right].value) {
            nodes[nodeId].right = rotateRight(nodes[nodeId].right);
            return rotateLeft(nodeId);
        }

        return nodeId;
    }

    function deleteValue(uint256 value) public {
        root = deleteRecursive(root, value);
    }

    function deleteRecursive(bytes32 nodeId, uint256 value) private returns (bytes32) {
        if (nodeId == bytes32(0)) {
            return nodeId; // Value not found
        }

        if (value < nodes[nodeId].value) {
            nodes[nodeId].left = deleteRecursive(nodes[nodeId].left, value);
        } else if (value > nodes[nodeId].value) {
            nodes[nodeId].right = deleteRecursive(nodes[nodeId].right, value);
        } else {
            // Node found
            if (nodes[nodeId].left == bytes32(0) || nodes[nodeId].right == bytes32(0)) {
                bytes32 child = nodes[nodeId].left != bytes32(0) ? nodes[nodeId].left : nodes[nodeId].right;

                if (child == bytes32(0)) {
                    // No child case
                    delete nodes[nodeId];
                    nodeCount--;
                    return bytes32(0);
                } else {
                    // One child case
                    Node memory childNode = nodes[child];
                    delete nodes[nodeId];
                    nodes[nodeId] = childNode;
                    delete nodes[child];
                    // Note: nodeCount unchanged since we're replacing rather than removing
                    nodeCount--;
                }
            } else {
                // Two children case
                bytes32 successor = minValueNode(nodes[nodeId].right);
                nodes[nodeId].value = nodes[successor].value;
                nodes[nodeId].right = deleteRecursive(nodes[nodeId].right, nodes[successor].value);
            }
        }

        if (nodeId == bytes32(0)) {
            return nodeId;
        }

        nodes[nodeId].height = 1 + max(getHeight(nodes[nodeId].left), getHeight(nodes[nodeId].right));

        int256 balance = getBalance(nodeId);

        // Rotations
        if (balance > 1 && getBalance(nodes[nodeId].left) >= 0) {
            return rotateRight(nodeId);
        }
        if (balance > 1 && getBalance(nodes[nodeId].left) < 0) {
            nodes[nodeId].left = rotateLeft(nodes[nodeId].left);
            return rotateRight(nodeId);
        }
        if (balance < -1 && getBalance(nodes[nodeId].right) <= 0) {
            return rotateLeft(nodeId);
        }
        if (balance < -1 && getBalance(nodes[nodeId].right) > 0) {
            nodes[nodeId].right = rotateRight(nodes[nodeId].right);
            return rotateLeft(nodeId);
        }

        return nodeId;
    }

    function minValueNode(bytes32 nodeId) private view returns (bytes32) {
        bytes32 current = nodeId;
        while (nodes[current].left != bytes32(0)) {
            current = nodes[current].left;
        }
        return current;
    }

    function getHeight(bytes32 nodeId) private view returns (uint256) {
        if (nodeId == bytes32(0)) {
            return 0;
        }
        return nodes[nodeId].height;
    }

    function getBalance(bytes32 nodeId) private view returns (int256) {
        if (nodeId == bytes32(0)) {
            return 0;
        }
        return int256(getHeight(nodes[nodeId].left)) - int256(getHeight(nodes[nodeId].right));
    }

    function rotateRight(bytes32 y) private returns (bytes32) {
        bytes32 x = nodes[y].left;
        bytes32 t2 = nodes[x].right;

        nodes[x].right = y;
        nodes[y].left = t2;

        nodes[y].height = 1 + max(getHeight(nodes[y].left), getHeight(nodes[y].right));
        nodes[x].height = 1 + max(getHeight(nodes[x].left), getHeight(nodes[x].right));

        return x;
    }

    function rotateLeft(bytes32 x) private returns (bytes32) {
        bytes32 y = nodes[x].right;
        bytes32 t2 = nodes[y].left;

        nodes[y].left = x;
        nodes[x].right = t2;

        nodes[x].height = 1 + max(getHeight(nodes[x].left), getHeight(nodes[x].right));
        nodes[y].height = 1 + max(getHeight(nodes[y].left), getHeight(nodes[y].right));

        return y;
    }

    function max(uint256 a, uint256 b) private pure returns (uint256) {
        return a > b ? a : b;
    }

    function getAscendingOrder() public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](20);
        uint256 index = 0;
        inOrderTraversal(root, result, index);
        return result;
    }

    function inOrderTraversal(bytes32 nodeId, uint256[] memory result, uint256 index) private view returns (uint256) {
        if (nodeId != bytes32(0) && index < 20) {
            index = inOrderTraversal(nodes[nodeId].left, result, index);
            if (index < 20) {
                result[index] = nodes[nodeId].value;
                index++;
                index = inOrderTraversal(nodes[nodeId].right, result, index);
            }
        }
        return index;
    }

    function getDescendingOrder() public view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](20);
        uint256 index = 0;
        reverseInOrderTraversal(root, result, index);
        return result;
    }

    function reverseInOrderTraversal(bytes32 nodeId, uint256[] memory result, uint256 index)
        private
        view
        returns (uint256)
    {
        if (nodeId != bytes32(0) && index < 20) {
            index = reverseInOrderTraversal(nodes[nodeId].right, result, index);
            if (index < 20) {
                result[index] = nodes[nodeId].value;
                index++;
                index = reverseInOrderTraversal(nodes[nodeId].left, result, index);
            }
        }
        return index;
    }
}
