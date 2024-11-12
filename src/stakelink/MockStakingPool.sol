//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract MockStakingPool {
    error InvalidDeposit();

    address mockPriorityPool;
    MockERC20 private immutable token;
    MockERC20 private immutable lst;

    uint256 totalStaked;
    uint256 unusedDepositLimit;

    constructor(address _mockPriorityPool, address _token, address _lst) {
        mockPriorityPool = _mockPriorityPool;
        token = MockERC20(_token);
        lst = MockERC20(_lst);
    }

    function deposit(address _account, uint256 _amount, bytes[] calldata _data) external {
        // require(strategies.length > 0, "Must be > 0 strategies to stake");

        uint256 startingBalance = token.balanceOf(address(this));

        if (_amount > 0) {
            token.transferFrom(msg.sender, address(this), _amount);
            // _depositLiquidity(_data);
            _mint(_account, _amount);
            totalStaked += _amount;
        }
        // } else {
        //     _depositLiquidity(_data);
        // }

        uint256 endingBalance = token.balanceOf(address(this));
        if (endingBalance > startingBalance && endingBalance > 1000e18) {
            revert InvalidDeposit();
        }
    }

    function donateTokens(uint256 _amount) external {
        token.transferFrom(msg.sender, address(this), _amount);
        totalStaked += _amount;
        // emit DonateTokens(msg.sender, _amount);
    }

    function _mint(address _to, uint256 _amount) internal {
        lst.mint(_to, _amount);
    }

    function canDeposit() external view returns (uint256) {
        uint256 max;

        if (max <= totalStaked) {
            return 0;
        } else {
            return max - totalStaked;
        }
    }
}
