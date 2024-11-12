//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Pool} from "../exchange/Pool.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

/*
 * This is a simplified lending protocol which by itself is the Vault
 * The only functionality it offers is to deposit stLink and use it as colleteral for 
 * USDC loans. The main purpose is to set a proof of profitability and showcase that the users 
 * of stake.link would be directly at harm. Credits to Cyfrin Updrafts lesson
 * about decentralized stablecoins, which the basic functionality came from
*/

contract LendingProtocol {
    Pool pool;
    MockERC20 usdc;
    MockERC20 token;
    MockERC20 lst;

    uint256 private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint256 private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUDATION_PRECISION = 100;
    uint256 constant PRICE_CHAINLINK = 11e18;

    mapping(address user => mapping(address collateralToken => uint256 amount)) public s_collateralDeposited;
    mapping(address user => uint256 usdLoaned) public amountLoaned;
    address[] private s_collateralTokens;

    constructor(Pool _pool, address _usdc, address _stLink, address _link) {
        pool = _pool;
        usdc = MockERC20(_usdc);
        lst = MockERC20(_stLink);
        token = MockERC20(_link);
    }

    function deposit(uint256 amountCollateral) public payable {
        s_collateralDeposited[msg.sender][address(lst)] += amountCollateral;
        bool success = MockERC20(address(lst)).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert("Deposit Didnt work.");
        }
    }

    function takeLoan() public payable {
        uint256 amountCollateral = s_collateralDeposited[msg.sender][address(lst)];
        uint256 lstValueUsd = _getUsdValue();
        uint256 loanAmount = amountCollateral * lstValueUsd / 2;
        usdc.transfer(msg.sender, loanAmount);
        amountLoaned[msg.sender] += loanAmount;
    }

    function getHealthFactor(address _user) public view returns (uint256) {
        uint256 collateralValueInUsd;
        uint256 outstandingDebt;
        // Here we use out of necessarity the Pool as oracle.
        collateralValueInUsd = _getUsdValue();
        outstandingDebt = amountLoaned[_user];

        return ((s_collateralDeposited[_user][address(lst)] * collateralValueInUsd) / outstandingDebt);
    }

    function _getUsdValue() public view returns (uint256) {
        uint256 collateralValueInUsd;
        // Here we use out of necessarity the Pool as oracle.
        uint256 inputAmount;
        uint256 inputReserves = token.balanceOf(address(pool));
        uint256 outputReserves = lst.balanceOf(address(pool));

        inputAmount = pool.getInputAmountBasedOnOutput(1e18, inputReserves, outputReserves);

        // Here we assume a Chainlink price of 11 USD per token, this would usually be a chainlink pricefeed or a secondary call
        // But it does not matter for our example where this call is coming from. The Chainlink/USDC liquidity is sufficiently backed
        // so that our trade in the LINK/USDC pool is neglectable. Even if we would take it into account:
        // If the price of Chainlink would be higher because of our other trade, the results for the price of stLink would be even more catastrophical
        // The Goal is now to evaluate stLink in USD so we can assume a value for the health factor, a simplified way to do that is
        // Supply stLink / Supply Link  * USD value of Chainlink
        return collateralValueInUsd = outputReserves / inputReserves * PRICE_CHAINLINK;
    }

    function liquidate(address user) public payable {
        uint256 startingUserHealthFactor = getHealthFactor(user);

        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert("Manipulation Failed, Health factor of User is still good!");
        }
        uint256 amountCollateral = s_collateralDeposited[user][address(lst)];
        bool success = lst.transfer(msg.sender, amountCollateral);
        if (!success) {
            revert("Transfer Failed at liquidation");
        }
    }

    function getColleteralDeposited(address user, address _token) public view returns (uint256) {
        return s_collateralDeposited[user][_token];
    }

    receive() external payable {}
}
