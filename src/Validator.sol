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

    mapping(uint256 => uint256) public totalStakedLicensesPerEpoch;                 // How many licences were staked in total for the current epoch
    mapping(uint256 => uint256) public licensesLockTime;                            // Time when each license was locked(tokenId => stake time)
    mapping(address => uint256) public validatorRewards;                            // Amount of rewards earned by validator
    mapping(uint256 => address) public tokenOwner;

    mapping(uint256 => uint256) public rewardPerLicenseAccumulated;                 // Accumulated rewards per license at each epoch
    mapping(address => uint256) public lastClaimedEpoch;                            // Track when a validator's claim last changed

    mapping(address => uint256) public lastStakeUpdateEpoch;                        // Track when a validator's stake last changed
    mapping(address => uint256) public stakesAtLastUpdate;                          // Track the stake amount at the last update     
    
    constructor(
        uint256 _epochDuration, 
        uint256 _rewardDecayRate, 
        uint256 _initialRewards,
        address _licenseToken, 
        address _rewardToken
    ) Ownable(msg.sender) {
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
        
        uint256 _currentEpoch = currentEpoch;
        stakesAtLastUpdate[msg.sender] += 1;
        lastStakeUpdateEpoch[msg.sender] = _currentEpoch;
        licensesLockTime[_tokenId] = block.timestamp;
        totalStakedLicensesPerEpoch[_currentEpoch] += 1;
        tokenOwner[_tokenId] = msg.sender;
        lastClaimedEpoch[msg.sender] = _currentEpoch - 1; // Initialize for first-time validators

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

        require(stakesAtLastUpdate[msg.sender] > 0, "No licenses to unlock");
        stakesAtLastUpdate[msg.sender] -= 1;
        lastStakeUpdateEpoch[msg.sender] = currentEpoch;
        delete licensesLockTime[_tokenId];
        delete tokenOwner[_tokenId];
        totalStakedLicensesPerEpoch[currentEpoch] -= 1;

        licenseToken.safeTransferFrom(address(this), msg.sender, _tokenId);
    }
    
    /**
     * @dev Transfers earned tokens(ERC-20) to validator. Rewards are calculated on-demand
     * based on the validator's staked licenses and epochs passed since last claim.
     *
     * Function restrictions:
     *  - can only be called when the contract is not on pause.
    */
    function claimRewards() external whenNotPaused {
        uint256 lastClaimed = lastClaimedEpoch[msg.sender];
    
        if (lastClaimed >= currentEpoch) {
            revert Validator_EpochAlreadyClaimed();
        }
        if (lastClaimed == 0) {
            lastClaimed = currentEpoch - 1; // First time claiming
        }

        uint256 rewards = _calculateUserRewards(msg.sender, lastClaimed);
        if (rewards == 0) {
            revert Validator_NoRewardsToClaim();
        }
        
        // Update state before external call to prevent reentrancy
        lastClaimedEpoch[msg.sender] = currentEpoch;
        
        rewardToken.safeTransfer(msg.sender, rewards);
    }

    /**
     * @dev Calculates rewards for a validator since their last claim
     * 
     * @param _validator Address of the validator
     * @param _lastClaimedEpoch Last epoch this validator claimed rewards for
     * @return total rewards accumulated since last claim
     */
    function _calculateUserRewards(address _validator, uint256 _lastClaimedEpoch) internal view returns (uint256) {
        if (_validator == address(0)) {
            return 0;
        }
        
        uint256 totalRewards = 0;
        uint256 _currentEpoch = currentEpoch;

        for (uint256 epoch = _lastClaimedEpoch + 1; epoch < _currentEpoch; epoch++) {
            uint256 validatorStake = getValidatorStakeAtEpoch(_validator, epoch);
            if (validatorStake > 0) {
                // Calculate the reward for this specific epoch using the difference between adjacent epochs
                uint256 epochReward = validatorStake * (
                    rewardPerLicenseAccumulated[epoch] - rewardPerLicenseAccumulated[epoch - 1] // This difference represents the rewards earned per license during the current epoch.
                );
                totalRewards += epochReward;
            }
        }
        
        return totalRewards;
    }

    /**
     * @dev End the current epoch and update reward state for the next epoch.
     * Instead of calculating rewards for each validator immediately, we update
     * the accumulated rewards per license that will be used for on-demand calculations.
     * 
     * Function restrictions:
     *  - only contract owner can call this function
    */
    function epochEnd() external onlyOwner {
        if (currentEpochRewards == 0) {
            revert Validator_NoRewardsInPool();
        }
        if (block.timestamp < lastEpochTime + epochDuration) {
            revert Validator_EpochNotFinishedYet();
        }
        
        uint256 _currentEpoch = currentEpoch;
        uint256 totalStakedEpochLicenses = totalStakedLicensesPerEpoch[_currentEpoch];

        // Update accumulated rewards per license
        if (totalStakedEpochLicenses > 0) {
            uint256 rewardPerLicense = (currentEpochRewards * PRECISION) / totalStakedEpochLicenses;
            rewardPerLicenseAccumulated[_currentEpoch] = rewardPerLicenseAccumulated[_currentEpoch - 1] + rewardPerLicense;
            
            // Move stakes to next epoch
            totalStakedLicensesPerEpoch[_currentEpoch + 1] = totalStakedEpochLicenses;
        }
        
        // Decrease rewards for the next epoch
        currentEpochRewards = (currentEpochRewards * (100 - rewardDecayRate) * PRECISION) / (100 * PRECISION);
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
     * @dev Returns the length of `validators` array.
     * @return uint256 length of the array. 
    */
    function getValidatorsLength() public view returns (uint256) {
        return validators.length;
    }
    
    /**
     * @dev Returns the stake amount for a validator at a specific epoch.
     * 
     * @param _validator Address of the validator
     * @param _epoch Epoch number
     * @return uint256 Stake amount at the specified epoch
    */
    function getValidatorStakeAtEpoch(address _validator, uint256 _epoch) public view returns (uint256) {
        uint256 lastUpdate = lastStakeUpdateEpoch[_validator];

        // If the stake was updated after the requested epoch, return 0
        if (lastUpdate > _epoch) return 0;
    
        // Otherwise, return the stake at the last update
        return stakesAtLastUpdate[_validator];
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
        if (msg.sender != address(licenseToken)) {    
            revert Validator_CanOnlyBeCalledByLicenseTokenContract(msg.sender);
        }
        return this.onERC721Received.selector;
    }

    /**
     * @dev Public function to view user rewards.
     * 
     * @param _validator Address of the validator
     * @return  amount of rewards for user.
     */
    function getUserRewards(address _validator) external view returns (uint256) {
        uint256 lastClaimed = lastClaimedEpoch[_validator];
        if (lastClaimed == 0) {
            lastClaimed = currentEpoch - 1; // First time viewing rewards
        }
        
        if (lastClaimed >= currentEpoch) {
            return 0;
        }
        
        return _calculateUserRewards(_validator, lastClaimed);
    }
}