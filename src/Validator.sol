// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/utils/Pausable.sol";
import {IValidatorErrors} from "./interfaces/utils/ICustomErrors.sol";

/**
 * @title Validator Contract
 * @author Anton
 * @notice This contract allows validators to stake their licenses(ERC-721) and earn tokens(ERC-20) in return
 * when a certain epoch is elapsed.
 */
contract Validator is Pausable, IValidatorErrors {
    using SafeERC20 for IERC20;

    event LicenseLocked(address indexed validator, uint256 tokenId);

    IERC20 public immutable rewardToken;                                            // ERC-20 token used for rewards
    IERC721 public immutable licenseToken;                                          // ERC-721 token used for licenses

    uint256 public immutable epochDuration;                                         // Duration of an epoch in minutes
    uint256 public immutable rewardDecayRate;                                       // Percentage of rewards to decrease per epoch (e.g., 10 means 10%)
    uint256 public currentEpoch;                                                    // Current epoch(means active epoch at the moment)
    uint256 public currentEpochRewards;                                             // Total rewards in current epoch(current - means active epoch)
    uint256 public lastEpochTime;                                                   // Timestamp when the last epoch ended

    mapping(address => mapping(uint256 => uint256)) public validatorStakesPerEpoch; // How many licenses each validator staked per epoch
    mapping(uint256 => uint256) public totalStakedLicensesPerEpoch;                 // How many licences were staked in total for the current epoch
    mapping(uint256 => uint256) public licensesLockTime;                            // Time when each license was locked(tokenId => stake time)
    mapping(address => uint256) public validatorRewards;                            // Amount of rewards earned by validator
    mapping(address => bool) public isValidatorTracked;                             // Mapping to check if validator is already in teh system(avoid double adding valiadtor to the system if he wants to add more than 1 license)

    address[] private validators;                                                   // Set of all addresses who have locked at least one license

    /**
     * @dev Modifier checks if function is called by token owner. If it is not a token owner
     * function reverts with error `Validator_NotOwner(spender)`, where `spender` is the person
     * who calling a function.
     * 
     * Modifier uses Yul to save gas. It is storing error selector and error argument value in the
     * memory scratch space. This avoids calculating free memory pointer, and as a result save gas.
     */
    modifier isOwner(uint256 _tokenId) {
        address owner = licenseToken.ownerOf(_tokenId);
        assembly {
            if iszero(eq(caller(), owner)) {                                                     // if msg.sender != token owner
                mstore(0x00, 0xdb16be5e00000000000000000000000000000000000000000000000000000000) // store error selector in 0x00 scratch space
                mstore(add(0x00, 4), caller()) //encode msg.sender(`spender`)

                revert(0x00, 36)
            }
        } 
        _;
    }

    constructor(
        uint256 _epochDuration, 
        uint256 _rewardDecayRate, 
        uint256 _epochRewards,
        IERC721 _licenseToken, 
        IERC20 _rewardToken
    ) {
        if (_epochDuration == 0) {
            revert Validator_EpochDurationCanNotBeZero();
        }
        if (_rewardDecayRate > 100) {
            revert Validator_RewardDecayRateCanNotBeGt100();
        }

        epochDuration = _epochDuration;
        rewardDecayRate = _rewardDecayRate;
        currentEpoch = 1;
        currentEpochRewards = _epochRewards;
        lastEpochTime = block.timestamp;
        licenseToken = _licenseToken;
        rewardToken = _rewardToken;
    }

    /**
     * @dev Locks a license(ERC721) in the contract and registers the validator for rewards.
     * 
     * Function restrictions:
     *  - can only be called when contract is not on pause.
     *  - only token owner can lock his license.
     *  - token owner should approve contract to spend his token, before calling this function.
     * 
     * Emits {LicenseLocked} event.
     * 
     * * @param _tokenId id of the token(ERC-721) which represents valiadtor license.
     */
    function lockLicense(uint256 _tokenId) external whenNotPaused isOwner(_tokenId) {
        if (licenseToken.getApproved(_tokenId) != address(this)) {
            revert Validator_ContractNotApprovedToStakeLicense();
        }

        licensesLockTime[_tokenId] =  block.timestamp;
        validatorStakesPerEpoch[msg.sender][currentEpoch] += 1;
        totalStakedLicensesPerEpoch[currentEpoch] += 1;

        if (!isValidatorTracked[msg.sender]) {      // verify if validator already exists
            validators.push(msg.sender);            
            isValidatorTracked[msg.sender] = true;  
        }

        licenseToken.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit LicenseLocked(msg.sender, _tokenId);
    }

    /**
     * @dev Unlocks a license(ERC-721) and returns it back to the owner.
     * 
     * Function restrictions:
     *  - can only be called when contract is not on pause.
     *  - only token owner can unlock his license.
     *  - can only be called when 1 full epoch has passed since the lock time.
     * 
     * @param _tokenId id of the token(ERC-721) which represents valiadtor license.
     */
    function unlockLicense(uint256 _tokenId) external whenNotPaused isOwner(_tokenId) {
        if (block.timestamp < licensesLockTime[_tokenId] + epochDuration) {
            revert Validator_EpochDidNotPassedYet();
        }

        delete licensesLockTime[_tokenId];
        validatorStakesPerEpoch[msg.sender][currentEpoch] -= 1;
        totalStakedLicensesPerEpoch[currentEpoch] -= 1;


        licenseToken.safeTransferFrom(address(this), msg.sender, _tokenId);
    }
    
    /**
     * @dev Transfers earned tokens(ERC-20) to valiadtor. Rewards are proportional to the number 
     * of staked licenses and number of elapsed epochs to valiadtor.
     * 
     * Function restrictions:
     *  - can only be called when contract is not on pause.
     */
    function claimRewards() external whenNotPaused {
        uint256 rewards = validatorRewards[msg.sender];
        if (rewards == 0) {
            revert Validator_NoRewardsToClaim();
        }
        
        validatorRewards[msg.sender] = 0;

        rewardToken.safeTransfer(msg.sender, rewards);
    }

    /**
     * @dev Distributes rewards for the epoch that has ended by calculating each validator's share and reward
     * in that epoch. Then adds the corresponding amount to `validatorRewards` balance.
     * Resets for the next epoch and decreases the total reward for the next epoch.
     */
    function epochEnd() external {
        if (block.timestamp < lastEpochTime + epochDuration) {                               // ensuring that func. can only be called after `epochDuration` time has elapsed since the `lastEpochTime`
            revert Validator_EpochNotFinishedYet();
        }

        uint256 totalStakedEpochLicenses = totalStakedLicensesPerEpoch[currentEpoch];        // get number of total locked licenses in the current epoch                           
        
        if (totalStakedEpochLicenses > 0 && currentEpochRewards > 0) {                       // check that we have both locked licenses and enough rewards in this epoch
            uint256 validatorsAmount = validators.length;                                    // caching the array length to save gas in the loop
            for (uint i = 0; i < validatorsAmount; i++) {
                address validator = validators[i];
                uint256 stakedInEpoch = validatorStakesPerEpoch[validator][currentEpoch];    // get `validator` locked licenses in `currentEpoch`
                if (stakedInEpoch == 0) {                                                    // if `validator` do not have staked licenses in the current epoch, then just skip this iteration
                    continue;
                }
                validatorRewards[validator] +=_calculateRewards(                             // calculate rewards for specific `validator` in this epoch 
                    validator, 
                    stakedInEpoch, 
                    totalStakedEpochLicenses
                );
            }
        }
        // Formula for calculating rewards for the future epoch: fixed rewards in current epoch * (100 - fixed decay rate) / 100.
        // Ex: Total rewards = 1000; decay rate = 10% in each epoch. This means that total rewards amount
        // will be decresing in each epoch by 10%. Then 1000 * (100 - 10) / 100 = 900 total rewards for the next epoch
        currentEpochRewards = currentEpochRewards * (100 - rewardDecayRate) / 100;           // Decrease rewards for the next epoch by fixed `rewardDecayRate`
        lastEpochTime = block.timestamp;
        currentEpoch += 1;
    }
    
    /**
     * @dev Calculates rewards for `_validator` in the `currentEpoch`. Calculation happens 
     * one time when epoch is finished. Results are calculated based on the number of validator 
     *  `_stakedInEpoch` licenses and `_totalEpochLicenses` locked in current epoch from all validators.
     * lisenses
     * 
     * Function restrictions:
     *  - `_validator` can not be address(0)
     * 
     * @param _validator user who staked his/ger licenses.
     * @param _stakedInEpoch number of locked `_vaidator` licenses in the currentEpoch.
     * @param _totalEpochLicenses total number of locked licenses in the currentEpoch from all validators.
     * 
     * @return reward amount earned by user per `currentEpoch`.
     */
    function _calculateRewards(
        address _validator, 
        uint256 _stakedInEpoch, 
        uint256 _totalEpochLicenses
    ) internal view returns(uint256 reward) {
        if (_validator == address(0)) {
            revert Validator_ValidatorCanNotBeAddressZero();
        }
        // Formula: (total locked validator licenses * 1e18) / total locked licenses. This will give us
        // the share of validator from all locked licenses.
        // Using 1e18 helps to prevent precision loss with division adn more easier fractional calculations.
        uint256 validatorShare = (_stakedInEpoch * 1e18) / _totalEpochLicenses;
        // Formula: (Total reward in current epoch * validator share in pool of locked licenses) / 1e18.
        reward = (currentEpochRewards * validatorShare) / 1e18;
    }

    function pauseContract() external {
        _pause();
    }

    function unpauseContract() external {
        _unpause();
    }
}