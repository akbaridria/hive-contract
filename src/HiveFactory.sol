// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HiveCore.sol";
import "./TokenSort.sol";

contract HiveFactory {
    using TokenSort for address;

    // Array to store all deployed HiveCore contract addresses
    address[] public hiveCores;

    // Mapping to store the unique pool identifier for a pair of tokens
    mapping(bytes32 => address) public getHiveCore;

    // Event emitted when a new HiveCore is created
    event HiveCoreCreated(address indexed hiveCoreAddress, address indexed baseToken, address indexed quoteToken);

    /**
     * @dev Deploys a new HiveCore contract with the given base and quote tokens.
     * @param baseToken The address of the base token.
     * @param quoteToken The address of the quote token.
     * @return The address of the newly deployed HiveCore contract.
     */
    function createHiveCore(address baseToken, address quoteToken) external returns (address) {
        // Ensure the tokens are valid
        require(baseToken != address(0), "HiveFactory: INVALID_BASE_TOKEN");
        require(quoteToken != address(0), "HiveFactory: INVALID_QUOTE_TOKEN");
        require(baseToken != quoteToken, "HiveFactory: IDENTICAL_TOKENS");

        // Sort tokens to generate a unique pool identifier
        (address token0, address token1) = TokenSort.sortTokens(baseToken, quoteToken);
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1));

        // Ensure the pool does not already exist
        require(getHiveCore[poolId] == address(0), "HiveFactory: POOL_ALREADY_EXISTS");

        // Deploy a new HiveCore contract with the original token order
        HiveCore hiveCore = new HiveCore(baseToken, quoteToken);

        // Store the address of the deployed contract
        hiveCores.push(address(hiveCore));
        getHiveCore[poolId] = address(hiveCore);

        // Emit an event with the details of the deployed contract
        emit HiveCoreCreated(address(hiveCore), baseToken, quoteToken);

        // Return the address of the deployed contract
        return address(hiveCore);
    }

    /**
     * @dev Returns the number of deployed HiveCore contracts.
     * @return The number of deployed HiveCore contracts.
     */
    function getHiveCoreCount() external view returns (uint256) {
        return hiveCores.length;
    }

    /**
     * @dev Returns the address of a deployed HiveCore contract by index.
     * @param index The index of the HiveCore contract.
     * @return The address of the HiveCore contract.
     */
    function getHiveCoreByIndex(uint256 index) external view returns (address) {
        require(index < hiveCores.length, "HiveFactory: INDEX_OUT_OF_BOUNDS");
        return hiveCores[index];
    }

    /**
     * @dev Returns all deployed HiveCore contract addresses.
     * @return An array of all deployed HiveCore contract addresses.
     */
    function getAllHiveCores() external view returns (address[] memory) {
        return hiveCores;
    }
}
