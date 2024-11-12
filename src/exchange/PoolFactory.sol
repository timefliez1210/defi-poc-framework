//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Pool} from "./Pool.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

/*
 * This is just a very minimal, quite standard pool factory and 
 * pool contract. The basis is taken from the Tswap example in 
 * the cyfrin updraft security course.
 */

contract PoolFactory {
    error PoolFactory__PoolAlreadyExists(address tokenAddress);
    error PoolFactory__PoolDoesNotExist(address tokenAddress);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    mapping(address token => address pool) private s_pools;
    mapping(address pool => address token) private s_tokens;

    address private immutable i_wethToken;

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/
    event PoolCreated(address tokenAddress, address poolAddress);

    /*//////////////////////////////////////////////////////////////
                               FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    constructor(address wethToken) {
        i_wethToken = wethToken;
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    function createPool(address tokenAddress) external returns (address) {
        if (s_pools[tokenAddress] != address(0)) {
            revert PoolFactory__PoolAlreadyExists(tokenAddress);
        }
        string memory liquidityTokenName = string.concat("T-Swap ", IERC20(tokenAddress).name());
        string memory liquidityTokenSymbol = string.concat("ts", IERC20(tokenAddress).name());
        Pool pool = new Pool(tokenAddress, i_wethToken, liquidityTokenName, liquidityTokenSymbol);
        s_pools[tokenAddress] = address(pool);
        s_tokens[address(pool)] = tokenAddress;
        emit PoolCreated(tokenAddress, address(pool));
        return address(pool);
    }

    /*//////////////////////////////////////////////////////////////
                   EXTERNAL AND PUBLIC VIEW AND PURE
    //////////////////////////////////////////////////////////////*/
    function getPool(address tokenAddress) external view returns (address) {
        return s_pools[tokenAddress];
    }

    function getToken(address pool) external view returns (address) {
        return s_tokens[pool];
    }

    function getWethToken() external view returns (address) {
        return i_wethToken;
    }
}
