//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Pool} from "../../src/exchange/Pool.sol";
import {FlashLoanProvider} from "../../src/flashloan/FlashLoanProvider.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract FlashLoanConsumerTwo {
    FlashLoanProvider loan;
    Pool poolLinkStlink;
    Pool poolLinkUSDC;
    // Create Staked Chainlink token
    MockERC20 lst = new MockERC20("STAKED LINK", "stLINK", 18);
    // Create Chainlink token
    MockERC20 token = new MockERC20("CHAINLINK", "LINK", 18);
    // Create a Mock USDC
    MockERC20 usdc = new MockERC20("USDC", "USDC", 18);

    bytes params;

    constructor(FlashLoanProvider _flashLoanProvider) {
        loan = FlashLoanProvider(_flashLoanProvider);
    }

    function _takeFlashLoan(uint256 _amount) public payable {
        loan.flashloan(address(this), usdc, _amount, params);
    }

    function _repayFlashLoan(uint256 _amount) public payable {
        loan.repay(usdc, _amount);
    }

    receive() external payable {}
}
