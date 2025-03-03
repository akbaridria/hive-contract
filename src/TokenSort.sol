// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TokenSort {
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, "TokenSort: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "TokenSort: ZERO_ADDRESS");
    }
}
