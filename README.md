# 


## Description

The deposit Chain of PriorityPool and StakingPool lets users deposit Link and receive stLink within a single transaction, which can be exploited 
to manipulate the peg between stLink and Link and therefor harm legitimate users and holders of stLink.


## Vulnerable Code

```PriorityPool::deposit```

```javascript
function deposit(uint256 _amount, bool _shouldQueue, bytes[] calldata _data) external {
        if (_amount == 0) revert InvalidAmount();
        token.safeTransferFrom(msg.sender, address(this), _amount);
1. @>   _deposit(msg.sender, _amount, _shouldQueue, _data);
    }
```

```PriorityPool::_deposit```

```javascript
function _deposit(
        address _account,
        uint256 _amount,
        bool _shouldQueue,
        bytes[] memory _data
    ) internal {
        if (poolStatus != PoolStatus.OPEN) revert DepositsDisabled();
        uint256 toDeposit = _amount;
2. @>   if (totalQueued == 0) {
            uint256 queuedWithdrawals = withdrawalPool.getTotalQueuedWithdrawals();
                
            if (queuedWithdrawals != 0) {
                uint256 toDepositIntoQueue = toDeposit <= queuedWithdrawals
                    ? toDeposit
                    : queuedWithdrawals;
                withdrawalPool.deposit(toDepositIntoQueue);
                toDeposit -= toDepositIntoQueue;
                IERC20Upgradeable(address(stakingPool)).safeTransfer(_account, toDepositIntoQueue);
            }
            if (toDeposit != 0) {
                uint256 canDeposit = stakingPool.canDeposit();
                if (canDeposit != 0) {      
                    uint256 toDepositIntoPool = toDeposit <= canDeposit ? toDeposit : canDeposit;
3. @>               stakingPool.deposit(_account, toDepositIntoPool, _data);
                    toDeposit -= toDepositIntoPool;
                }
            }
        }
        if (toDeposit != 0) {
            if (_shouldQueue) {
                _requireNotPaused();
                if (accountIndexes[_account] == 0) {
                    accounts.push(_account);
                    accountIndexes[_account] = accounts.length - 1;
                }
                accountQueuedTokens[_account] += toDeposit;
                totalQueued += toDeposit;
            } else {
                token.safeTransfer(_account, toDeposit);
            }
        }
        emit Deposit(_account, _amount - toDeposit, _shouldQueue ? toDeposit : 0);
    }
```

```StakingPool::deposit```

```javascript
function deposit(
        address _account,
        uint256 _amount,
        bytes[] calldata _data
    ) external onlyPriorityPool {
        require(strategies.length > 0, "Must be > 0 strategies to stake");
        uint256 startingBalance = token.balanceOf(address(this));
        if (_amount > 0) {
            token.safeTransferFrom(msg.sender, address(this), _amount);
            _depositLiquidity(_data);
4. @>       _mint(_account, _amount);
            totalStaked += _amount;
        } else {
            _depositLiquidity(_data);
        }
        uint256 endingBalance = token.balanceOf(address(this));
        if (endingBalance > startingBalance && endingBalance > unusedDepositLimit)
            revert InvalidDeposit();
    }
```


The points within the code 1. - 4. are all invokable within 1 call. We would call ```StakingPool::canDeposit``` to know how big our flashloan must be to fill the pool, than use the loan to buy the needed Chainlink tokens and invoke `PriorityPool::deposit` basically with the parameters ```deposit(amount StakingPool.canDeposit, false, bytes)``` which than triggers the deposit chain 2., 3. up to 4th the mint function, which allows us access to a vast amount of tokens without buying them.


## Impact

By potentially having access to stLink for a short duration of time, without buying it, the price of stLink compared to Link can be artifiaclly manipulatable downwards. This can directly harm regular stLink users using the liquid staking token on third party services (lending plattforms, exchanges etc.), since those third party services rely on the stLink and Link peg to calculate the fair stLink price. 


## Limitations

1. The proposed attack vector relies on the return value of ```StakingPool::canDeposit``` to be sufficient enough, compared to liquidity pools, to move the price downwards enough to effect health factors etc. of third party protocols.
2. Third parties need to integrate with stLink.

These limitations though could be met, with either several users withdrawing at once, or one big stLink holder withdrawing. Considering that the current liquidity within e.g. curve.finance on ethereum is at roughly 170k stLink and Link which equals a provided stLink value in USD of roughly 2,380,000 
USD it does not at all unlikely.
Secondly the attack vector would be possible if the stake.link protocol were to be deployed on L2 chains to open up for users (e.g. Arbitrum or Metis) or for other staking programs like Ether.

The second limitation should be straight forward, if other DeFi protocols 
should not integrate on LSTs it would defeat the purpose of such, users could
just stake directly.

Therefor my estimate for severity of the scenario would be:

Impact: High (direct user funds at risk)

Likelihood: Medium (the attack path is conditional)

Severity: High


## Proof of Concept

Within this repo you find a simplified mock version of ```PriorityPool``` and ```StakingPool```. Also a simplified exchange, flashloan provider and a lending protocol.
You may validate the following proposed attack path by running the commands ```forge build``` and ```forge test -vvv``` or ```forge test --fork-url https://mainnet.infura.io/v3/${your_infura_api_key} -vvv```. 

An attacker takes 2 flashloans

Flashloan 1 will be used to buy Link and stake it in return for stLink.

Flashloan 2 will be used to liquidate users on lending protocols, provide liquidity or open short positions.

Flashloan 1 will be used to sell stLink for Link (in this example. It could as well be other exchange pairs), which will decrease the value of stLink compared to Link and therefor USD.

Flashloan 2 will now be used to liquidate users of stLink which use their LST to take a loan on a lending protocol, and other arbitrary logic which profits from a rapid downwards movement in price.

Flashloan 1 will now be attempted to be repaid, but since it can not (insufficient balance) it will revert, moving the liquidity pool and therefor price back into it's original state.

Flashloan 2 will now sell stLink proceeds into Link and into the currency it was taken in. Flashloan 2 is repaid and valid.



This attack path differs from commonly used oracle manipulations in the point that stake.link itself provides the liquidity needed to manipulate the price downwards and therefor harm other legitimate users.


## Recommended Mitigations

1. Disable the possibility of a user to deposit and mint within the same transaction by enforcing a timelock on the mint after deposit.

2. Provide an oracle which protocols can use to get the fair price backed by reserve holdings and exchange TWAPS.