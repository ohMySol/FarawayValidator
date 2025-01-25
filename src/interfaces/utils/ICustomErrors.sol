// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

// Custom errors for Validator.sol
interface IValiadtorErrors {

}

// Custom errors for HelperConfig.s.sol
interface IHelperConfigErrors {
    /**
     * @dev Error indicates that a user is trying to deploy a contract to a network which 
     * is not supported.
     */
    error HelperConfig_NonSupportedChain();
}