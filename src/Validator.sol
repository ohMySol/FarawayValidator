// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IValidatorErrors} from "./interfaces/utils/ICustomErrors.sol";

/**
 * @title Validator Contract
 * @author Anton
 * @notice This contract allows validators to stake their licenses(ERC-721) and earn tokens(ERC-20) in return
 * when a certain epoch(time period) has elapsed.
*/
contract Validator is Pausable, Ownable, IERC721Receiver,  IValidatorErrors {
    using SafeERC20 for IERC20;

    event LicenseLocked(address indexed validator, uint256 tokenId);

    IERC20 public immutable rewardToken;                                            // ERC-20 token used for rewards
    IERC721 public immutable licenseToken;                                          // ERC-721 token used for licenses


    uint256 public constant PRECISION = 1e18;
    uint256 public immutable epochDuration;                                         // Duration of an epoch in minutes
    uint256 public immutable rewardDecayRate;                                       // Percentage of rewards to decrease per epoch (e.g., 10 means 10%)
    uint256 public currentEpoch;                                                    // Current epoch(means active epoch at the moment)
    uint256 public currentEpochRewards;                                             // Total rewards in current epoch(current - means active epoch)
    uint256 public lastEpochTime;                                                   // Timestamp when the last epoch ended
    address[] public validators;                                                    // Set of all addresses who have locked at least one license

    mapping(address => mapping(uint256 => uint256)) public validatorStakesPerEpoch; // How many licenses each validator staked per epoch
    mapping(uint256 => uint256) public totalStakedLicensesPerEpoch;                 // How many licences were staked in total for the current epoch
    mapping(uint256 => uint256) public licensesLockTime;                            // Time when each license was locked(tokenId => stake time)
    mapping(address => uint256) public validatorRewards;                            // Amount of rewards earned by validator
    mapping(address => bool) public isValidatorTracked;                             // Mapping to check if validator is already in the system(avoid double adding validator to the system if he wants to add more than 1 license)
    mapping(uint256 => address) public tokenOwner;

    constructor(
        uint256 _epochDuration, 
        uint256 _rewardDecayRate, 
        uint256 _initialRewards,
        address _licenseToken, 
        address _rewardToken
    ) Ownable(msg.sender) {
        if (_epochDuration == 0 || _rewardDecayRate == 0 || _initialRewards == 0) {         // ensure critical values for future calculations set up correctly
            revert Validator_ConstructorInitialValuesCanNotBeZero(
                _epochDuration, _rewardDecayRate, _initialRewards
            );
        }
        if (_rewardDecayRate > 100) {                                                       // ensure the decay rate remains a valid % between 0% and 100%, because if it is more, then it would result in a negative multiplier in `epochEnd` calcualtion
            revert Validator_ConstructorRewardDecayRateCanNotBeGt100();
        }
        if (_licenseToken == address(0) || _rewardToken == address(0)) {                    // ensure token contracts are set up correctly
            revert Validator_ConstructorZeroAddressNotAllowed(_licenseToken, _rewardToken);
        }

        epochDuration = _epochDuration;
        rewardDecayRate = _rewardDecayRate;
        currentEpoch = 1;
        currentEpochRewards = _initialRewards;
        lastEpochTime = block.timestamp;
        licenseToken = IERC721(_licenseToken);
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @dev Locks a license(ERC721) in the contract and registers the validator for rewards.
     * 
     * Function restrictions:
     *  - can only be called when the contract is not on pause.
     *  - only token owner can lock his license.
     *  - token owner should approve a contract to spend his token, before calling this function.
     * 
     * Emits {LicenseLocked} event.
     * 
     * @param _tokenId id of the token(ERC-721) which represents validator license.
    */
    function lockLicense(uint256 _tokenId) external whenNotPaused {
        if (licenseToken.ownerOf(_tokenId) != msg.sender) {
            revert Validator_NotTokenOwner();
        }
        if (licenseToken.getApproved(_tokenId) != address(this)) {
            revert Validator_ContractNotApprovedToStakeLicense();
        }

        licensesLockTime[_tokenId] =  block.timestamp;
        validatorStakesPerEpoch[msg.sender][currentEpoch] += 1;
        totalStakedLicensesPerEpoch[currentEpoch] += 1;
        tokenOwner[_tokenId] = msg.sender;

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
     *  - can only be called when the contract is not on pause.
     *  - only the token owner can unlock his license.
     *  - can only be called when 1 full epoch has passed since the lock time.
     * 
     * @param _tokenId id of the token(ERC-721) which represents validator license.
    */
    function unlockLicense(uint256 _tokenId) external whenNotPaused {
        if (tokenOwner[_tokenId] != msg.sender) {
            revert Validator_NotTokenOwner();
        }
        if (block.timestamp < licensesLockTime[_tokenId] + epochDuration) {
            revert Validator_EpochDidNotPassedYet();
        }

        delete licensesLockTime[_tokenId];
        delete tokenOwner[_tokenId];
        validatorStakesPerEpoch[msg.sender][currentEpoch] -= 1;
        totalStakedLicensesPerEpoch[currentEpoch] -= 1;


        licenseToken.safeTransferFrom(address(this), msg.sender, _tokenId);
    }
    
    /**
     * @dev Transfers earned tokens(ERC-20) to validator. Rewards are proportional to the number
     * of staked licenses and number of elapsed epochs to validator.
     *
     * Function restrictions:
     *  - can only be called when the contract is not on pause.
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
     * 
     * Function restrictions:
     *  - only contract owner can call this function(in future it is possible to automate this)
    */
    function epochEnd() external onlyOwner {
        if (currentEpochRewards == 0) {
            revert Validator_NoRewardsInPool();
        }
        if (block.timestamp < lastEpochTime + epochDuration) {                               // ensuring that func. can only be called after `epochDuration` time has elapsed since the `lastEpochTime`
            revert Validator_EpochNotFinishedYet();
        }
        
        uint256 _currentEpoch = currentEpoch;                                                // caching currentEpoch value
        uint256 totalStakedEpochLicenses = totalStakedLicensesPerEpoch[_currentEpoch];       // get number of total locked licenses in the current epoch                            

        if (totalStakedEpochLicenses > 0) {                                                  // check that we have both locked licenses and enough rewards in this epoch
            uint256 validatorsAmount = validators.length;                                    // caching the array length to save gas in the loop
            for (uint i = 0; i < validatorsAmount; i++) {
                address validator = validators[i];
                uint256 stakedInEpoch = validatorStakesPerEpoch[validator][_currentEpoch];   // get `validator` locked licenses in `currentEpoch`
                
                if (stakedInEpoch == 0) {                                                    // if `validator` do not have staked licenses in the current epoch, then just skip this iteration
                    continue;
                }
                
                validatorRewards[validator] += _calculateRewards(                            // calculate rewards for specific `validator` in this epoch 
                    validator, 
                    stakedInEpoch, 
                    totalStakedEpochLicenses
                );
                
                validatorStakesPerEpoch[validator][_currentEpoch + 1] = stakedInEpoch;       // move validator stakes from the current epoch -> to the next epoch
            }
            totalStakedLicensesPerEpoch[_currentEpoch + 1] = totalStakedEpochLicenses;       // move total staked tokens from the current epoch -> to the next epoch
        }
        // Formula for calculating rewards for the future epoch: fixed rewards in current epoch * (100 - fixed decay rate) / 100.
        // Ex: Total rewards = 1000; decay rate = 10% in each epoch. This means that total rewards amount
        // will be decreasing in each epoch by 10%. Then 1000 * (100 - 10) / 100 = 900 total rewards for the next epoch
        currentEpochRewards = (currentEpochRewards * (100 - rewardDecayRate) * PRECISION) / (100 * PRECISION);      // Decrease rewards for the next epoch by fixed `rewardDecayRate` | using 1e18(PRECISION) helps to prevent precision loss with division
        lastEpochTime = block.timestamp;
        currentEpoch += 1;
    }
    
    /**
     * @dev Sets contract on pause in case of emergency(e.g. critical vulnerability was found).
     * Functions with `whenNotPaused` modifier will be locked, until contract will be unlocked.
     * 
     * Function restrictions:
     *  - only contract owner can call this function
    */
    function pauseContract() external onlyOwner {
        _pause();
    }

    /**
     * @dev Removes contract from pause.
     * Functions with `whenNotPaused` modifier will be unlocked for use.
     * 
     * Function restrictions:
     *  - only contract owner can call this function
    */
    function unpauseContract() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Calculates rewards for `_validator` in the `currentEpoch`. Calculation happens 
     * one time when the epoch is finished. Results are calculated based on the number of validator 
     * `_stakedInEpoch` licenses and `_totalEpochLicenses` locked in the current epoch from all validators.
     * licenses
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
        // the share of the validator from all locked licenses.
        // Using 1e18 helps to prevent precision loss with division and more easier fractional calculations.
        uint256 validatorShare = (_stakedInEpoch * PRECISION) / _totalEpochLicenses;
        // Formula: (Total reward in current epoch * validator share in pool of locked licenses) / 1e18.
        reward = (currentEpochRewards * validatorShare) / PRECISION;
    }

    /**
     * @dev Returns the length of `validators` array.
     * @return uint256 length of the array. 
    */
    function getValidatorsLength() public view returns (uint256) {
        return validators.length;
    }

    /**
     * @dev Function ensuring that this contract can properly receive ERC-721 tokens via
     * `safeTransferFrom()` function. 
     * 
     * Function restrictions:
     *  - can only be called by `LicenseToken` contract.
     * 
     * @return selector of the `onERC721Received()` function is returned.
    */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external view override returns (bytes4) {
        if (msg.sender != address(licenseToken)) {      // verify msg.sender is the `LicenseToken` contract.
            revert Validator_CanOnlyBeCalledByLicenseTokenContract(msg.sender);
        }
        return this.onERC721Received.selector;
    }
}