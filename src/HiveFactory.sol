// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./HiveCore.sol";
import "./library/TokenSort.sol";
import "./interfaces/IHiveFactory.sol";

contract HiveFactory is IHiveFactory {
    using TokenSort for address;

    address[] public hiveCores;

    mapping(bytes32 => address) public getHiveCore;
    mapping(address => address) public whitelistQuoteTokens;

    modifier onlyQuoteToken(address quoteToken) {
        require(whitelistQuoteTokens[quoteToken] != address(0), "HiveFactory: QUOTE_TOKEN_NOT_WHITELISTED");
        _;
    }

    constructor(address[] memory quoteTokens) {
        for (uint256 i = 0; i < quoteTokens.length; i++) {
            require(quoteTokens[i] != address(0), "HiveFactory: INVALID_QUOTE_TOKEN");
            whitelistQuoteTokens[quoteTokens[i]] = quoteTokens[i];
        }
    }

    /**
     * @dev Deploys a new HiveCore contract with the given base and quote tokens.
     * @param baseToken The address of the base token.
     * @param quoteToken The address of the quote token.
     * @return The address of the newly deployed HiveCore contract.
     */
    function createHiveCore(address baseToken, address quoteToken)
        external
        override
        onlyQuoteToken(quoteToken)
        returns (address)
    {
        require(baseToken != address(0), "HiveFactory: INVALID_BASE_TOKEN");
        require(quoteToken != address(0), "HiveFactory: INVALID_QUOTE_TOKEN");
        require(baseToken != quoteToken, "HiveFactory: IDENTICAL_TOKENS");

        (address token0, address token1) = TokenSort.sortTokens(baseToken, quoteToken);
        bytes32 poolId = keccak256(abi.encodePacked(token0, token1));

        require(getHiveCore[poolId] == address(0), "HiveFactory: POOL_ALREADY_EXISTS");

        HiveCore hiveCore = new HiveCore(baseToken, quoteToken);

        hiveCores.push(address(hiveCore));
        getHiveCore[poolId] = address(hiveCore);

        emit HiveCoreCreated(address(hiveCore), baseToken, quoteToken);

        return address(hiveCore);
    }

    /**
     * @dev Returns the number of deployed HiveCore contracts.
     * @return The number of deployed HiveCore contracts.
     */
    function getHiveCoreCount() external view override returns (uint256) {
        return hiveCores.length;
    }

    /**
     * @dev Returns the address of a deployed HiveCore contract by index.
     * @param index The index of the HiveCore contract.
     * @return The address of the HiveCore contract.
     */
    function getHiveCoreByIndex(uint256 index) external view override returns (address) {
        require(index < hiveCores.length, "HiveFactory: INDEX_OUT_OF_BOUNDS");
        return hiveCores[index];
    }

    /**
     * @dev Returns all deployed HiveCore contract addresses.
     * @return An array of all deployed HiveCore contract addresses.
     */
    function getAllHiveCores() external view override returns (address[] memory) {
        return hiveCores;
    }

    /**
     * @dev Adds a quote token to the whitelist.
     * @param quoteToken The address of the quote token.
     */
    function addQuoteToken(address quoteToken) external override {
        require(quoteToken != address(0), "HiveFactory: INVALID_QUOTE_TOKEN");
        require(whitelistQuoteTokens[quoteToken] == address(0), "HiveFactory: QUOTE_TOKEN_ALREADY_WHITELISTED");

        whitelistQuoteTokens[quoteToken] = quoteToken;

        emit QuoteTokenAdded(quoteToken);
    }
}
