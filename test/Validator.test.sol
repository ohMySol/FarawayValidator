// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Validator} from  "../src/Validator.sol";
import {RewardToken} from  "../src/RewardToken.sol";
import {LicenseToken} from  "../src/LicenseToken.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DeployValidator} from "../script/deploy/DeployValidator.s.sol";
import {IValidatorErrors} from "../src/interfaces/utils/ICustomErrors.sol";

contract ValidatorTest is Test {
    Validator public validator;
    LicenseToken public licenseToken;
    RewardToken public rewardToken;
    HelperConfig.NetworkConfig public config;

    address public admin; 
    address public manager;
    address public alice;
   
    function setUp() public {
        DeployValidator deployer = new DeployValidator();
        (validator, config) = deployer.deploy();            // get network `config` and `validator` instance.
        
        licenseToken = LicenseToken(config.licenseToken);   // create instance of `LicenseToken` contract
        rewardToken = RewardToken(config.rewardToken);      // create instance of `RewardToken` contract

        admin = vm.addr(config.adminPk);
        alice = makeAddr("alice");
    }

    /*//////////////////////////////////////////////////
                INITIALIZATION TESTS
    /////////////////////////////////////////////////*/
    function test_ValidatorContract_Initialized_With_Correct_Values() public {
        assertEq(address(validator.licenseToken()), config.licenseToken);
        assertEq(address(validator.rewardToken()), config.rewardToken);
        assertEq(validator.epochDuration(), config.epochDuration);
        assertEq(validator.epochDuration(), config.epochDuration);
        assertEq(validator.rewardDecayRate(), config.rewardDecayRate);
        assertEq(validator.currentEpoch(), 1);
        assertEq(validator.currentEpochRewards(), config.initialRewards);
        assertEq(validator.lastEpochTime(), block.timestamp);
    }
}