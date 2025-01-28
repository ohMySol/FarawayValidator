// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "../src/Validator.sol";

/**
 * @dev This is a test helper contract, which inherits from the main `Validator` contract. 
 * It wraps the internal functions into external functions and allows testing the internal 
 * logic without modifying the original contract.
 */
contract InternalFunctionsHarness is Validator {
    constructor(
        uint256 _epochDuration,
        uint256 _rewardDecayRate,
        uint256 _epochRewards,
        address _licenseToken,
        address _rewardToken
    ) Validator(
        _epochDuration,
        _rewardDecayRate,
        _epochRewards,
        _licenseToken,
        _rewardToken
    ) {}

    function calculateRewards(
        address _validator, 
        uint256 _stakedInEpoch, 
        uint256 _totalEpochLicenses
    ) external view returns (uint256 reward) {
        return _calculateRewards(_validator, _stakedInEpoch, _totalEpochLicenses);
    } 

    function syncRewardPool(uint256 _currentRewardPool) external {
        currentEpochRewards = _currentRewardPool;
    }
}