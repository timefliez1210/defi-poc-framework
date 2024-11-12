//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Pool} from "../../src/exchange/Pool.sol";
import {FlashLoanProvider} from "../../src/flashloan/FlashLoanProvider.sol";
import {MockPriorityPool} from "../../src/stakelink/MockPriorityPool.sol";
import {MockStakingPool} from "../../src/stakelink/MockStakingPool.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract FlashLoanConsumerOne {
    MockStakingPool stakingPool;
    MockPriorityPool priorityPool;
    Pool pool;
    FlashLoanProvider loan;
    MockERC20 usdc;
    MockERC20 token;
    MockERC20 lst;

    bytes params;

    constructor(
        MockPriorityPool _mockPrio,
        Pool _poolLinkStlink,
        MockStakingPool _mockStaking,
        FlashLoanProvider _flashLoanProvider,
        address _usdc,
        address _stLink,
        address _link
    ) {
        loan = FlashLoanProvider(_flashLoanProvider);
        pool = Pool(_poolLinkStlink);
        priorityPool = MockPriorityPool(_mockPrio);
        stakingPool = MockStakingPool(_mockStaking);
        usdc = MockERC20(_usdc);
        lst = MockERC20(_stLink);
        token = MockERC20(_link);
    }

    function _takeFlashLoan(uint256 _amount) public payable {
        loan.flashloan(address(this), usdc, _amount, params);
    }

    function _repayFlashLoan(uint256 _amount) public payable {
        loan.repay(usdc, _amount);
    }

    receive() external payable {}
}
