// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/**
 * @title Validator Contract
 * @author Anton
 * @notice This contract allows validators to stake their licenses(ERC-721) and earn tokens(ERC-20) in return.
 */
contract Validator {
    /**
     * @dev Locks a license(ERC721) in the contract and registers the validator for rewards.
     * 
     * Emits {LicenseLocked} event.
     */
    function lockLicense(uint256 _tokenId) external {}

    /**
     * @dev Unlocks a license(ERC-721) and returns it back to the owner.
     * 
     * Restrictions:
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