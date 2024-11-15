//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {MockStakingPool} from "./MockStakingPool.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract MockPriorityPool {
    error InvalidAmount();

    MockERC20 private immutable token;
    MockStakingPool stakingPool;

    constructor(address _token) {
        token = MockERC20(_token);
    }

    function initializeMockStakingPool(address _mockStakingPool) external {
        stakingPool = MockStakingPool(_mockStakingPool);
    }

    /**
     * @notice Deposits asset tokens into the staking pool and/or queues them
     * @param _amount amount to deposit
     * @param _shouldQueue whether tokens should be queued if there's no room in the staking pool
     * @param _data deposit data passed to staking pool strategies
     */
    function deposit(address _account, uint256 _amount, bool _shouldQueue, bytes[] calldata _data) external {
        if (_amount == 0) revert InvalidAmount();
        token.transferFrom(_account, address(this), _amount);
        _deposit(_account, _amount, _shouldQueue, _data);
    }

    /**
     * @notice Deposits asset tokens into the withdrawal pool, staking pool, and/or queues them
     * @dev tokens will be deposited into the withdrawal pool if there are queued withdrawals, then the
     * staking pool if there is deposit room. Remaining tokens will then be queued if `_shouldQueue`
     * is true, or otherwise returned to sender
     * @param _account account to deposit for
     * @param _amount amount to deposit
     * @param _shouldQueue whether tokens should be queued
     * @param _data deposit data passed to staking pool strategies
     *
     */
    function _deposit(address _account, uint256 _amount, bool _shouldQueue, bytes[] memory _data) internal {
        // commented out since irrelevant to set up
        // if (poolStatus != PoolStatus.OPEN) revert DepositsDisabled();

        uint256 toDeposit = _amount;
        uint256 totalQueued = 0;

        if (totalQueued == 0) {

            // This part is safe to comment out, since it handles the case if there
            // are queued withdrawals. So the contract, if there are, would anyway
            // give us the LST here. Otherwise it is commented out to circumvent deploying
            // the withdrawal pool in this Test Suite

            // uint256 queuedWithdrawals = withdrawalPool.getTotalQueuedWithdrawals();
            // if (queuedWithdrawals != 0) {
            //     uint256 toDepositIntoQueue = toDeposit <= queuedWithdrawals
            //         ? toDeposit
            //         : queuedWithdrawals;
            //     withdrawalPool.deposit(toDepositIntoQueue);
            //     toDeposit -= toDepositIntoQueue;
            //     IERC20Upgradeable(address(stakingPool)).safeTransfer(_account, toDepositIntoQueue);
            // }

            if (toDeposit != 0) {

                // Arbitrary value instead of calling the function simply
                // because to prove the attack path it doesnt matter
                // In reality we would need to assume that stakingPool.canDeposit()
                // returns a value high enough compared to existing liquidity

                uint256 canDeposit = 100e18; //stakingPool.canDeposit();
                if (canDeposit != 0) {
                    uint256 toDepositIntoPool = toDeposit <= canDeposit ? toDeposit : canDeposit;
                    stakingPool.deposit(_account, toDepositIntoPool, _data);
                    toDeposit -= toDepositIntoPool;
                }
            }
        }
        
        // This part is safe to comment out, since it only handles the case
        // if the staking pool cant consume this deposit aKa the pool is full.
        // if (toDeposit != 0) {
        //     if (_shouldQueue) {
        //         _requireNotPaused();
        //         if (accountIndexes[_account] == 0) {
        //             accounts.push(_account);
        //             accountIndexes[_account] = accounts.length - 1;
        //         }
        //         accountQueuedTokens[_account] += toDeposit;
        //         totalQueued += toDeposit;
        //     } else {
        //         token.safeTransfer(_account, toDeposit);
        //     }
        // }

        // emit Deposit(_account, _amount - toDeposit, _shouldQueue ? toDeposit : 0);
    }

    receive() external payable {}
}
