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

    uint256 public epochDuration;           // Duration of an epoch in minutes
    uint256 public rewardDecayRate;         // Percentage of rewards to decrease per epoch (e.g., 10 means 10%)
    
    IERC20 public immutable rewardToken;    // ERC-20 token used as rewards
    IERC721 public immutable licenseToken;  // ERC-721 token used as licenses

    struct Stake {
        uint256 lockTime;        // Time when the license was locked
        uint256 elapsedEpochs;   // Number of elapsed epochs
    }

    mapping (address => uint256) public numberOfStakedLicenses; // Number of staked licences by each validator
    mapping(uint256 => Stake) public stakes;                    // Information about each staked license

    event LicenseLocked(address indexed validator, uint256 tokenId);

    constructor(
        uint256 _epochDuration, 
        uint256 _rewardDecayRate, 
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
        licenseToken = _licenseToken;
        rewardToken = _rewardToken;
    }

    /**
     * @dev Locks a license(ERC721) in the contract and registers the validator for rewards.
     * 
     * Function restrictions:
     *  - can only be called when contract is not on pause.
     *  - token owner should approve contract to spend his token, before calling this function.
     * 
     * Emits {LicenseLocked} event.
     */
    function lockLicense(uint256 _tokenId) external whenNotPaused {
        if (licenseToken.getApproved(_tokenId) != address(this)) {
            revert Validator_ContractNotApprovedToStakeLicense();
        }

        stakes[_tokenId] = Stake({
            lockTime: block.timestamp,
            elapsedEpochs: 0
        });
        numberOfStakedLicenses[msg.sender] += 1;
        licenseToken.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit LicenseLocked(msg.sender, _tokenId);
    }

    /**
     * @dev Unlocks a license(ERC-721) and returns it back to the owner.
     * 
     * Function restrictions:
     *  - can only be called when 1 full epoch has passed since the lock time.
     */
    function unlockLicense(uint256 _tokenId) external {}
    
    /**
     * @dev Transfers earned tokens(ERC-20) that are proportional to the number of staked licenses
     * and number of elapsed epochs to valiadtor.
     */
    function clainRewards() external {}

    /**
     * @dev Finishes the current epoch, distributes a rewards among validators, and decreses the 
     * reward pool for the next epoch.
     */
    function epochEnd() external {}
}