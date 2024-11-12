//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";
import {AssetToken} from "./AssetToken.sol";

/* 
 * This Flashloan contract has it's origins from the thunderloan 
 * protocol on cyfrin updraft. It is simplified for demonstration purposes.
 */

contract FlashLoanProvider {
    error ThunderLoan__NotAllowedToken(MockERC20 token);
    error ThunderLoan__CantBeZero();
    error ThunderLoan__NotPaidBack(uint256 expectedEndingBalance, uint256 endingBalance);
    error ThunderLoan__NotEnoughTokenBalance(uint256 startingBalance, uint256 amount);
    error ThunderLoan__CallerIsNotContract();
    error ThunderLoan__AlreadyAllowed();
    error ThunderLoan__ExhangeRateCanOnlyIncrease();
    error ThunderLoan__NotCurrentlyFlashLoaning();
    error ThunderLoan__BadNewFee();

    MockERC20 usdc;

    mapping(MockERC20 => AssetToken) public s_tokenToAssetToken;
    mapping(MockERC20 token => bool currentlyFlashLoaning) private s_currentlyFlashLoaning;

    modifier revertIfZero(uint256 amount) {
        if (amount == 0) {
            revert ThunderLoan__CantBeZero();
        }
        _;
    }

    constructor(address _usdc) {
        usdc = MockERC20(_usdc);
    }

    function deposit(MockERC20 token, uint256 amount) external payable {
        AssetToken assetToken = s_tokenToAssetToken[token];

        usdc.transferFrom(msg.sender, address(this), amount);
    }

    function flashloan(address receiverAddress, MockERC20 token, uint256 amount, bytes calldata params)
        external
        revertIfZero(amount)
    {
        // AssetToken assetToken = s_tokenToAssetToken[token];
        uint256 startingBalance = token.balanceOf(address(this));

        // if (amount > startingBalance) {
        //     revert ThunderLoan__NotEnoughTokenBalance(startingBalance, amount);
        // }

        if (receiverAddress.code.length == 0) {
            revert ThunderLoan__CallerIsNotContract();
        }

        s_currentlyFlashLoaning[token] = true;
        //usdc.transfer(receiverAddress, amount);
        // slither-disable-next-line unused-return reentrancy-vulnerabilities-2
        usdc.transfer(msg.sender, amount);

        uint256 endingBalance = token.balanceOf(address(this));
        if (endingBalance < startingBalance) {
            revert ThunderLoan__NotPaidBack(startingBalance, endingBalance);
        }
        s_currentlyFlashLoaning[token] = false;
    }

    function repay(MockERC20 token, uint256 amount) public {
        AssetToken assetToken = s_tokenToAssetToken[token];
        usdc.transferFrom(msg.sender, address(this), amount);
    }

    receive() external payable {}
}
