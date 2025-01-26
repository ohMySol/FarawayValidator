// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Custom errors for Validator.sol
interface IValidatorErrors {
    /**
     * @dev Error indicates that deployer is trying to deploy a contract with `_epochDuration` = 0.
     */
    error Validator_EpochDurationCanNotBeZero();

    /**
     * @dev Error indicates that deployer is trying to deploy a contract with `_rewardDecayRate` > 100.
     */
    error Validator_RewardDecayRateCanNotBeGt100();

    /**
     * @dev Error indicates that token owner didn't approve contract for staking the license.
     */
    error Validator_ContractNotApprovedToStakeLicense();

    /**
     * @dev Error indicates that validator is trying to unlock license, when at least 1 epoch
     * didn't passed yet.
     */
    error Validator_EpochDidNotPassedYet();

     /**
     * @dev Error indicates that address(0) is participating in rewards calculations.
     */
    error Validator_ValidatorCanNotBeAddressZero();

    /**
     * @dev Error indicates that user is calling epochEnd() function when the epoch didn't yet finish.
     */
    error Validator_EpochNotFinishedYet();

    /**
     * @dev Error indicates that validator already claimed his rewards in the current epoch.
     */
    error Validator_RewardAlreadyClaimedInThisEpoch();

    /**
     * @dev Error indicates that validator do not have any rewards to claim.
     */
    error Validator_NoRewardsToClaim();
}

// Custom errors for HelperConfig.s.sol
interface IHelperConfigErrors {
    /**
     * @dev Error indicates that a user is trying to deploy a contract to a network which 
     * is not supported.
     */
    error HelperConfig_NonSupportedChain();
}