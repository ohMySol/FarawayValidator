// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Custom errors for Validator.sol
interface IValidatorErrors {
    /**
     * @dev Error indicates that deployer is trying to deploy a contract with `_epochDuration` or 
     * `_rewardDecayRate` or `_initialRewards` argument = 0.
     */
    error Validator_ConstructorInitialValuesCanNotBeZero(
        uint256 epochDuration, 
        uint256 rewardDecayRate, 
        uint256 initialRewards
    );

    /**
     * @dev Error indicates that deployer is trying to deploy a contract with `_rewardDecayRate` argument > 100.
     */
    error Validator_ConstructorRewardDecayRateCanNotBeGt100();

    /**
     * @dev Error indicates that deployer is trying to deploy a contract with `_licenseToken` or 
     * `rewardToken` argument which is address(0).
     */
    error Validator_ConstructorZeroAddressNotAllowed(address licenseToken, address rewardToken);

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

    /**
     * @dev Error indicates that not a `LicenseToken` contract is calling a `safeTransferFrom` function.
     */
    error Validator_CanOnlyBeCalledByLicenseTokenContract(address caller);

    /**
     * @dev Error indicates that only token owner can lock/unlock his token(license) in/from the contract.
     */
    error Validator_NotTokenOwner();

    /**
     * @dev Error indicates that owner is trying to close an epoch and open a new epoch with 0 rewards pool. 
     */
    error Validator_NoRewardsInPool();
}

// Custom errors for HelperConfig.s.sol
interface IHelperConfigErrors {
    /**
     * @dev Error indicates that a user is trying to deploy a contract to a network which 
     * is not supported.
     */
    error HelperConfig_NonSupportedChain();
}