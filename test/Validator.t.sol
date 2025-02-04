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
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {InternalFunctionsHarness} from "./InternalFunctoinsHarness.sol";


contract ValidatorTest is Test {
    
    event LicenseLocked(address indexed validator, uint256 tokenId);
    
    Validator public validator;
    LicenseToken public licenseToken;
    RewardToken public rewardToken;
    HelperConfig.NetworkConfig public config;
    InternalFunctionsHarness public internalFunctionsHarness;

    address public admin; 
    address public manager;
    address public alice;
    address public bob;
    address public charlie;

    modifier beforeUnlock() { 
        vm.startPrank(alice);
        validator.lockLicense(0);  // alice locking her token
        _;
    }
   
    function setUp() public {
        DeployValidator deployer = new DeployValidator();
        (validator, config) = deployer.deploy();                    // get network `config` and `validator` instance.
        
        internalFunctionsHarness = new InternalFunctionsHarness(    // create instance for testing internal functions from `Validator` contract
            config.epochDuration,
            config.rewardDecayRate,
            config.initialRewards,
            config.licenseToken,
            config.rewardToken
        );

        licenseToken = LicenseToken(config.licenseToken);           // create instance of `LicenseToken` contract
        rewardToken = RewardToken(config.rewardToken);              // create instance of `RewardToken` contract

        admin = vm.addr(config.adminPk);                            // create owner account
        alice = makeAddr("alice");                                  // create alice test account
        bob = makeAddr("bob");                                      // create bob test account
        charlie = makeAddr("charlie");                              // create charlie test account
        
        vm.startPrank(admin);
        rewardToken.mint(address(validator), 1000000);              // mint reward tokens for `validator` contract

        for (uint256 i = 0; i < 3; i++) {                           // Mint and approve 10 NFTs for each user
            if (i == 0) {
                for (uint256 i = 0; i < 10; i++) {                  // Mint + approve for Alice 10 tokens (tokens 0-9)
                    vm.startPrank(admin);
                    licenseToken.safeMint(alice);
                    vm.startPrank(alice);
                    licenseToken.approve(address(validator), i);
                    vm.stopPrank();
                }
            } else if (i == 1) {
                for (uint256 i = 10; i < 20; i++) {                 // Mint + approve for Bob 10 tokens (tokens 0-9)
                    vm.startPrank(admin);
                    licenseToken.safeMint(bob);
                    vm.startPrank(bob);
                    licenseToken.approve(address(validator), i);
                    vm.stopPrank();
                }
            } else {
                for (uint256 i = 20; i < 30; i++) {                 // Mint + approve for Charlie 10 tokens (tokens 0-9)
                    vm.startPrank(admin);
                    licenseToken.safeMint(charlie);
                    vm.startPrank(charlie);
                    licenseToken.approve(address(validator), i);
                    vm.stopPrank();
                }
            }
        }
    }



    /*//////////////////////////////////////////////////
                HELPER FUNCTIONS
    /////////////////////////////////////////////////*/
    /**
     * @dev Function calculates an expected reward values for validators. These values are used
     * later in the tests.
     * 
     * @return uint256 reward for alice.
     * @return uint256 reward for bob. 
     * @return uint256 reward for charlie. 
     */
    function calculateExpectedRewards() public returns (uint256, uint256, uint256) {
        uint256 currentEpoch = validator.currentEpoch();
        uint256 totalStakedTokensPerEpoch = validator.totalStakedLicensesPerEpoch(currentEpoch);
        internalFunctionsHarness.syncRewardPool(validator.currentEpochRewards()); // synchronise harness and validator states. Without this line harness will useinitial reward pool in all epochs.
        

        // Calculate rewards for each validator
        uint256 aliceReward = internalFunctionsHarness.calculateRewards(
            alice,
            validator.validatorStakesPerEpoch(alice, currentEpoch),
            totalStakedTokensPerEpoch
        );
    
        uint256 bobReward = internalFunctionsHarness.calculateRewards(
            bob,
            validator.validatorStakesPerEpoch(bob, currentEpoch),
            totalStakedTokensPerEpoch
        );
    
        uint256 charlieReward = internalFunctionsHarness.calculateRewards(
            charlie,
            validator.validatorStakesPerEpoch(charlie, currentEpoch),
            totalStakedTokensPerEpoch
        );
    
        return (aliceReward, bobReward, charlieReward);
    }

    /**
     * @dev Function calculates an expected reward token pool value for the next epoch.
     * 
     * @return new reward pool value for the next epoch.
     */
    function calculateFutureEpochRewardPool() public view returns (uint256) {
        return validator.currentEpochRewards() * (100 - validator.rewardDecayRate()) / 100;
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

    function test_Constructor_Reverts_When_EpochDuration_Is_Zero() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IValidatorErrors.Validator_ConstructorInitialValuesCanNotBeZero.selector,
                0,
                config.rewardDecayRate,
                config.initialRewards
            )
        );
        new Validator(
            0,
            config.rewardDecayRate,
            config.initialRewards,
            config.licenseToken,
            config.rewardToken
        );
    }

    function test_Constructor_Reverts_When_RewardDecayRate_Greater_Than_100() public {
        vm.expectRevert(
            IValidatorErrors.Validator_ConstructorRewardDecayRateCanNotBeGt100.selector
        );
        new Validator(
            config.epochDuration,
            101,
            config.initialRewards,
            config.licenseToken,
            config.rewardToken
        );
    }

    function test_Constructor_Reverts_When_Token_Address_Is_0() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IValidatorErrors.Validator_ConstructorZeroAddressNotAllowed.selector,
                address(0),
                config.rewardToken
            )
        );
        new Validator(
            config.epochDuration,
            config.rewardDecayRate,
            config.initialRewards,
            address(0),
            config.rewardToken
        );
    }


    /*//////////////////////////////////////////////////
                lockLicense() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Validator_Successfully_Lock_LicenseToken() public {
        vm.startPrank(alice);
        validator.lockLicense(0);       // alice locks her license token

        uint256 currentEpoch = validator.currentEpoch();
        uint256 tokenLockTime = validator.licensesLockTime(0);
        uint256 amountOfAliceStakedTokensPerEpoch = validator.validatorStakesPerEpoch(alice, currentEpoch);
        uint256 totalStakedLicensesPerEpoch = validator.totalStakedLicensesPerEpoch(currentEpoch);
        bool isAliceRegistered = validator.isValidatorTracked(alice);
        address aliceValidator = validator.validators(0);
        address tokenOwner = validator.tokenOwner(0);

        assertEq(tokenLockTime, block.timestamp);
        assertEq(amountOfAliceStakedTokensPerEpoch, 1); // expect 1 - because never staked before
        assertEq(totalStakedLicensesPerEpoch, 1);       // expect 1 - because Alice is the only validator atm
        assertEq(isAliceRegistered, true);              // verify alice was registered as validator(before she wasn't)
        assertEq(aliceValidator, alice);                // verify alice was added to `validators`array(before she wasn't)
        assertEq(tokenOwner, alice);                    // verify alice was set as token owner in `tokenOwner` mapping
    }

    function test_After_Locking_ValidatorContract_Became_Token_Owner() public {
        vm.startPrank(alice);
        validator.lockLicense(0);

        address newTokenOwner = licenseToken.ownerOf(0);
        assertEq(newTokenOwner, address(validator));
    }

    function test_Event_Is_Emmitted_After_Token_Lock() public {
        vm.startPrank(alice);

        vm.recordLogs();                             // start recording logs
        validator.lockLicense(0);
        Vm.Log[] memory logs = vm.getRecordedLogs(); // receive all the recorded logs
        Vm.Log memory log = logs[1];                 // Event `LicenseLocked` is the second event in array

        bytes32 expectedEventHash = keccak256("LicenseLocked(address,uint256)");
        address validatorAddress = address(uint160(uint256(log.topics[1])));
        uint256 lockedTokenId = abi.decode(log.data, (uint256));

        assertEq(log.topics[0], expectedEventHash);  // verify correct event has was recorded in event topics
        assertEq(validatorAddress, alice);           // verify alice address is populated in event 
        assertEq(lockedTokenId, 0);                  // verify correct tokenId is populated in event
    }

    function test_ValidatorPerson_Successfully_Add_More_Than_One_Token() public {
        vm.startPrank(alice);
        
        validator.lockLicense(0);                                    // alice lock 1st token

        assertEq(validator.validators(0), alice);                    // verify that alice is included in `validators` array
        
        for (uint256 i = 1; i < 6; i++) {                            // alice lock +5 tokens
            validator.lockLicense(i);
        }                                  

        uint256 amountOfAliceStakedTokensPerEpoch = validator.validatorStakesPerEpoch(alice, validator.currentEpoch());
        uint256 totalStakedLicensesPerEpoch = validator.totalStakedLicensesPerEpoch(validator.currentEpoch());

        assertEq(amountOfAliceStakedTokensPerEpoch, 6);
        assertEq(totalStakedLicensesPerEpoch, 6);
    }

    function test_ValidatorPerson_Is_Added_Only_Once_To_Validators_Array() public {
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    vm.startPrank(alice);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            } else if (i == 1) {
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    vm.startPrank(bob);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            } else {
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    vm.startPrank(charlie);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            }
        }

        uint256 validatorsLength = validator.getValidatorsLength();

        assertEq(validatorsLength, 3);                     // verify that we have 3 entries in the array, because we have 3 individual validators
    }

    function test_Locking_Reverts_If_Contract_Is_On_Pause() public {
        vm.startPrank(admin);
        validator.pauseContract();      // contract owner put contract on pause

        vm.expectRevert(
            Pausable.EnforcedPause.selector
        );

        vm.startPrank(alice);                  
        validator.lockLicense(0);       // alice want to lock her licnese token, but call will revert
    }

    function test_Locking_Reverts_If_Not_A_Token_Owner_Call_Function() public {
        vm.startPrank(admin);
        
        vm.expectRevert(
            IValidatorErrors.Validator_NotTokenOwner.selector
        );

        validator.lockLicense(0);       // alice want to lock her licnese token, but call will revert
    }

    function test_Locking_Reverts_If_Owner_Did_Not_Approved_Contract_To_Spend_Token() public {
        vm.startPrank(admin);
        licenseToken.safeMint(alice);  // token id will be 30
        
        vm.startPrank(alice);
        vm.expectRevert(
            IValidatorErrors.Validator_ContractNotApprovedToStakeLicense.selector
        );

        validator.lockLicense(30);     // alice want to lock her licnese token, but call will revert
    }


    /*//////////////////////////////////////////////////
              unlockLicense() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Validator_Successfully_Unlock_LicenseToken() public beforeUnlock {
        vm.warp(validator.lastEpochTime() + 10 minutes);              // simulate that 1 epoch is elapsed
        
        vm.startPrank(alice);
        uint256 amountOfAliceStakedTokensPerEpoch = validator.validatorStakesPerEpoch(alice, validator.currentEpoch()); // check alice balance before unlock
        uint256 totalStakedLicensesPerEpoch = validator.totalStakedLicensesPerEpoch(validator.currentEpoch());          // check total balance before unlock
        // check that alice deposited 1 token
        assertEq(amountOfAliceStakedTokensPerEpoch, 1);
        assertEq(totalStakedLicensesPerEpoch, 1);
        assertEq(licenseToken.ownerOf(0), address(validator));
        
        validator.unlockLicense(0);

        uint256 _amountOfAliceStakedTokensPerEpoch = validator.validatorStakesPerEpoch(alice, validator.currentEpoch()); // check alice after unlock
        uint256 _totalStakedLicensesPerEpoch = validator.totalStakedLicensesPerEpoch(validator.currentEpoch());          // check total after unlock
        // check a successfull token unlock
        assertEq(_amountOfAliceStakedTokensPerEpoch, 0);    // verify alice stakes per epoch were deducted by 1
        assertEq(_totalStakedLicensesPerEpoch, 0);          // verify total number of stakes was deducted by 1
        assertEq(licenseToken.ownerOf(0), alice);           // verify that contract return ownership over the token back to alice
        assertEq(validator.licensesLockTime(0), 0);         // verify lock time for this token was cleared
        assertEq(validator.tokenOwner(0), address(0));      // verify token ownership was cleared
    }

    function test_Unlocking_Reverts_If_At_Least_1_Epoch_Not_Elapsed() public beforeUnlock {
        vm.startPrank(alice);
    
        vm.expectRevert(
            IValidatorErrors.Validator_EpochDidNotPassedYet.selector
        );
        
        validator.unlockLicense(0);
    }

    function test_Unlocking_Reverts_If_Not_A_Token_Owner_Calling_Function() public beforeUnlock {
        vm.warp(validator.lastEpochTime() + 10 minutes);  // simulate that 1 epoch is elapsed
        vm.startPrank(admin);
    
        vm.expectRevert(
            IValidatorErrors.Validator_NotTokenOwner.selector
        );
        
        validator.unlockLicense(0);
    }



    /*//////////////////////////////////////////////////
              pauseContract() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Contract_Successfully_Paused_By_Owner() public {
        vm.startPrank(admin);
        assertEq(validator.paused(), false);

        validator.pauseContract();
        assertEq(validator.paused(), true);
    }

    function test_Contract_Can_Be_Paused_Only_By_Contract_Owner() public {
        vm.startPrank(bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                bob
            )
        );
        validator.pauseContract();

        assertEq(validator.paused(), false);     // check that after unsuccessful pausing, the contract shouldn't be on pause
    }



    /*//////////////////////////////////////////////////
              unpauseContract() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Contract_Successfully_Unpaused_By_Owner() public {
        vm.startPrank(admin);
        validator.pauseContract();
        assertEq(validator.paused(), true);

        validator.unpauseContract();
        assertEq(validator.paused(), false);
    }

    function test_Contract_Can_Be_Unpaused_Only_By_Contract_Owner() public {
        vm.startPrank(admin);
        validator.pauseContract();

        vm.startPrank(bob);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                bob
            )
        );
        validator.unpauseContract();

        assertEq(validator.paused(), true);     // check that after unsuccessful unpausing, the contract should be on pause
    }



    /*//////////////////////////////////////////////////
              _calculateRewards() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Rewards_Calculated_Successfully_Based_On_Fourmula() public {
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    vm.startPrank(alice);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            } else if (i == 1) {
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    vm.startPrank(bob);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            } else {
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    vm.startPrank(charlie);
                    validator.lockLicense(i);
                    vm.stopPrank();
                }
            }
        }

        uint256 currentEpoch = validator.currentEpoch();
        uint256 aliceStakedTokensPerEpoch = validator.validatorStakesPerEpoch(alice, currentEpoch);         // get alice staked tokens
        uint256 bobStakedTokensPerEpoch = validator.validatorStakesPerEpoch(bob, currentEpoch);             // get bob staked tokens
        uint256 charlieStakedTokensPerEpoch = validator.validatorStakesPerEpoch(charlie, currentEpoch);     // get charlie staked tokens
        uint256 totalStakedTokensPerEpoch = validator.totalStakedLicensesPerEpoch(currentEpoch);            // get total staked tokens in contract(19)

        uint256 aliceReward = internalFunctionsHarness.calculateRewards(alice, aliceStakedTokensPerEpoch, totalStakedTokensPerEpoch);        // calculate reward for alice
        uint256 bobReward = internalFunctionsHarness.calculateRewards(bob, bobStakedTokensPerEpoch, totalStakedTokensPerEpoch);              // calculate reward for bob
        uint256 charlieReward = internalFunctionsHarness.calculateRewards(charlie, charlieStakedTokensPerEpoch, totalStakedTokensPerEpoch);  // calculate reward for charlie

        // calculated final results based on the formula in the contract
        assertEq(aliceReward, 315);
        assertEq(bobReward, 210);
        assertEq(charlieReward, 473);
    }

    function test_Calculation_Reverts_If_Validator_Address_Is_Zero() public {
        vm.expectRevert(
            IValidatorErrors.Validator_ValidatorCanNotBeAddressZero.selector
        );
        internalFunctionsHarness.calculateRewards(address(0), 6, 19);
    }



    /*//////////////////////////////////////////////////
              epochEnd() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    // Test verifies that function shoudl move to the next epoch stakes of each user(that are remained in the current epoch)
    // + total stakes in the contract. So that future epochs will be able to work with the correct state. 
    function test_EpochEnd_Moves_The_State_To_The_Next_Epoch() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected rewards for each validator in epoch 1.
        (
            uint256 expectedAliceRewardsPerEpoch1, 
            uint256 expectedBobRewardsPerEpoch1,
            uint256 expectedCharlieRewardsPerEpoch1
        ) = calculateExpectedRewards();

        uint256 expectedFutureRewardPool2 = calculateFutureEpochRewardPool();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();                              // contract owner closing current epoch, distributing rewards and calculating rewards pool for next epoch 2
        
        /////////////////////////////////// 2nd epoch ////////////////////////////////////////
        
        // 5. Get each user stakes balance and get the totak stakes balance in the contract.
        uint256 currentEpoch = validator.currentEpoch();
        uint256 aliceStakesInEpoch2 = validator.validatorStakesPerEpoch(alice, currentEpoch);
        uint256 bobStakesInEpoch2 = validator.validatorStakesPerEpoch(bob, currentEpoch);
        uint256 charlieStakesInEpoch2 = validator.validatorStakesPerEpoch(charlie, currentEpoch);
        uint256 totalStakesInEpoch2 = validator.totalStakedLicensesPerEpoch(currentEpoch);

        assertEq(currentEpoch, 2);
        assertEq(aliceStakesInEpoch2, 6);
        assertEq(bobStakesInEpoch2, 4);
        assertEq(charlieStakesInEpoch2, 9);
        assertEq(totalStakesInEpoch2, 19);
    }

    function test_EpochEnd_Successfully_Distributes_Rewards_For_Validators() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected rewards for each validator.
        (
            uint256 expectedAliceRewardsPerEpoch, 
            uint256 expectedBobRewardsPerEpoch,
            uint256 expectedCharlieRewardsPerEpoch
        ) = calculateExpectedRewards();
        
        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();                              // contract owner calling this function which closes current epoch, distributes rewards and calculate rewards pool for next epoch

        /////////////////////////////////// 1st epoch ////////////////////////////////////////

        // Get actual validators rewards from `validatorRewards` mapping.
        uint256 actualAliceRewardPerEpoch = validator.validatorRewards(alice);
        uint256 actualBobRewardPerEpoch = validator.validatorRewards(bob);
        uint256 actualCharlieRewardPerEpoch = validator.validatorRewards(charlie);
        
        assertEq(actualAliceRewardPerEpoch, expectedAliceRewardsPerEpoch);
        assertEq(actualBobRewardPerEpoch, expectedBobRewardsPerEpoch);
        assertEq(actualCharlieRewardPerEpoch, expectedCharlieRewardsPerEpoch);

    }

    function test_EpochEnd_Successfully_Decrease_RewardPool_For_Next_Epoch() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 
    
        // 3. Calculate expected reward pool value for the next epoch.
        uint256 expectedFutureRewardPool = calculateFutureEpochRewardPool();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();  

        /////////////////////////////////// 2nd epoch ////////////////////////////////////////


        // 5. Get actual value for new reward pool.
        uint256 actualNewRewardPool = validator.currentEpochRewards();

        assertEq(actualNewRewardPool, expectedFutureRewardPool);
        assertEq(validator.lastEpochTime(), block.timestamp);
        assertEq(validator.currentEpoch(), 2); // initially `currentEpoch` was 1
    }

    function test_EpochEnd_Countiniously_Distributes_Rewards_And_Adjuste_Rewards_And_RewardsPool() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected rewards for each validator in epoch 1.
        (
            uint256 expectedAliceRewardsPerEpoch1, 
            uint256 expectedBobRewardsPerEpoch1,
            uint256 expectedCharlieRewardsPerEpoch1
        ) = calculateExpectedRewards();

        uint256 expectedFutureRewardPool2 = calculateFutureEpochRewardPool();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();                              // contract owner calling this function which closes current epoch, distributes rewards and calculate rewards pool for next epoch 2
        
        /////////////////////////////////// 2nd epoch ////////////////////////////////////////

        assertEq(expectedFutureRewardPool2, validator.currentEpochRewards());

        // 5. Get actual validators rewards from `validatorRewards` mapping.
        uint256 actualAliceRewardPerEpoch1 = validator.validatorRewards(alice);
        uint256 actualBobRewardPerEpoch1 = validator.validatorRewards(bob);
        uint256 actualCharlieRewardPerEpoch1 = validator.validatorRewards(charlie);

        // 6. Imagine that some validators lock new tokens, and some unlock -> proportion of rewards will be changed for everyone
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 6; i < 8; i++) {          // alice locked 2 more licenses, so she has 8 licenses in epoch 2
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 12; i < 14; i++) {        // bob unlocked 2 licenses, so he has 2 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 25; i < 29; i++) {        // charlie unlocked 4 licenses, so she has 5 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 7. Move time forward to be able to finish epoch 2.
        vm.warp(validator.lastEpochTime() + 10 minutes); 
        
         // 8. Get expected rewards for each validator in epoch 2.
        (
            uint256 expectedAliceRewardsPerEpoch2, 
            uint256 expectedBobRewardsPerEpoch2,
            uint256 expectedCharlieRewardsPerEpoch2
        ) = calculateExpectedRewards();

        uint256 expectedFutureRewardPool3 = calculateFutureEpochRewardPool();

        // 9. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();  

        /////////////////////////////////// 3rd epoch ////////////////////////////////////////

        assertEq(expectedFutureRewardPool3, validator.currentEpochRewards());

        // 10. Get actual validators rewards from `validatorRewards` mapping(rewards should be a sum of prev. epoch + current epoch).
        uint256 actualAliceRewardPerEpoch2 = validator.validatorRewards(alice);
        uint256 actualBobRewardPerEpoch2 = validator.validatorRewards(bob);
        uint256 actualCharlieRewardPerEpoch2 = validator.validatorRewards(charlie);

        // 11. Verify that users reward balances are correctly updated
        // In this test users didn't claim any rewards before, they just continue staking, so that's why I am 
        // do a sum of expectedRewardsPerEpoch2 + expectedRewardsPerEpoch1. This will let us know
        // the amount of rewards for everyone in the end of the epoch 2.
        assertEq(expectedAliceRewardsPerEpoch2 + expectedAliceRewardsPerEpoch1, actualAliceRewardPerEpoch2);
        assertEq(expectedBobRewardsPerEpoch2 + expectedBobRewardsPerEpoch1, actualBobRewardPerEpoch2);
        assertEq(expectedCharlieRewardsPerEpoch2 + expectedCharlieRewardsPerEpoch1, actualCharlieRewardPerEpoch2);
    }

    // For example alice had 5 licenses in the 1st epoch. In the 2nd epoch she decided to unlock all her
    // tokens. This means that in the 2nd epoch alice won't have any tokens in stake -> and as a result 
    // reward calculation won't be done for alice(because she has no tokens in 2nd epoch). So test verifies
    // that users with no  license balance won't participate in reward calculation.
    function test_EpochEnd_Skips_RewardCalculation_For_Validators_With_0_Staked_Licenses() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected rewards for each validator in epoch 1.
        (
            uint256 expectedAliceRewardsPerEpoch1, 
            uint256 expectedBobRewardsPerEpoch1,
            uint256 expectedCharlieRewardsPerEpoch1
        ) = calculateExpectedRewards();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();                              // contract owner calling this function which closes current epoch, distributes rewards and calculate rewards pool for next epoch 2
        
        /////////////////////////////////// 2nd epoch ////////////////////////////////////////
        
        // 5. Get actual validators rewards from `validatorRewards` mapping.
        uint256 actualAliceRewardPerEpoch1 = validator.validatorRewards(alice);
        uint256 actualBobRewardPerEpoch1 = validator.validatorRewards(bob);
        uint256 actualCharlieRewardPerEpoch1 = validator.validatorRewards(charlie);

        // 6. Imagine that some validators lock new tokens, and some unlock -> proportion of rewards will be changed for everyone
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice unlocked all 6 licenses staked before, so she has 0 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 12; i < 14; i++) {        // bob unlocked 2 licenses, so he has 2 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 25; i < 29; i++) {        // charlie unlocked 4 licenses, so she has 5 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 7. Move time forward to be able to finish epoch 2.
        vm.warp(validator.lastEpochTime() + 10 minutes); 
        
         // 8. Get expected rewards for each validator in epoch 2.
        (
            uint256 expectedAliceRewardsPerEpoch2, 
            uint256 expectedBobRewardsPerEpoch2,
            uint256 expectedCharlieRewardsPerEpoch2
        ) = calculateExpectedRewards();

        // 9. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();  

        /////////////////////////////////// 3rd epoch ////////////////////////////////////////
        
        // 10. Get actual validators rewards from `validatorRewards` mapping(rewards should be a sum of prev. epoch + current epoch).
        uint256 actualAliceRewardPerEpoch2 = validator.validatorRewards(alice);
        uint256 actualBobRewardPerEpoch2 = validator.validatorRewards(bob);
        uint256 actualCharlieRewardPerEpoch2 = validator.validatorRewards(charlie);

        // 11. Verify that users reward balances are correctly updated.
        // Alice rewards won't be updated in epoch 2, because she staked 0 tokens in epoch 2.
        assertEq(expectedAliceRewardsPerEpoch2 + expectedAliceRewardsPerEpoch1, actualAliceRewardPerEpoch2);
        assertEq(expectedBobRewardsPerEpoch2 + expectedBobRewardsPerEpoch1, actualBobRewardPerEpoch2);
        assertEq(expectedCharlieRewardsPerEpoch2 + expectedCharlieRewardsPerEpoch1, actualCharlieRewardPerEpoch2);
    }

    // Test verifies that reward pool will be decreased even if total staked amount of licenses is 0
    // in the current epoch.
    function test_EpochEnd_Updates_RewardPool_Even_Without_Any_Staked_License_In_Contract() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice locked 6 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob locked 4 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie locked 9 licenses in epoch
                    validator.lockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected future reward pool for epoch 2.
        uint256 expectedFutureRewardPool2 = calculateFutureEpochRewardPool();


        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();                              // contract owner calling this function which closes current epoch, distributes rewards and calculate rewards pool for next epoch 2
        
        /////////////////////////////////// 2nd epoch ////////////////////////////////////////

        assertEq(expectedFutureRewardPool2, validator.currentEpochRewards());

        // 5. Imagine that each validator unlocked all his/her licenses in epoch 2. So total licenses will be 0.
        for (uint256 i = 0; i < 3; i++) {
            if (i == 0) {
                vm.startPrank(alice);
                for (uint256 i = 0; i < 6; i++) {          // alice unlocked all 6 licenses staked before, so she has 0 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            } else if (i == 1) {
                vm.startPrank(bob);
                for (uint256 i = 10; i < 14; i++) {        // bob unlocked 4 licenses, so he has 0 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            } else {
                vm.startPrank(charlie);
                for (uint256 i = 20; i < 29; i++) {        // charlie unlocked 9 licenses, so she has 0 licenses in epoch 2
                    validator.unlockLicense(i);
                }
                vm.stopPrank();
            }
        }

        // 6. Move time forward to be able to finish epoch 2.
        vm.warp(validator.lastEpochTime() + 10 minutes); 
        
        // 7. Get expected future reward pool for epoch 3.
        uint256 expectedFutureRewardPool3 = calculateFutureEpochRewardPool();

        // 8. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();   // close epoch with 0 total staked licenses and calculate new revard pool value  

        /////////////////////////////////// 3rd epoch ////////////////////////////////////////
        
        // 9. Get actual reward pool value in 3rd epoch.
        assertEq(expectedFutureRewardPool3, validator.currentEpochRewards()); // confirms that even without staked licenses, new revard pool value will be calculated.
    }

    function test_EpochEnd_Can_Only_Be_Called_By_Contract_Owner() public {
        vm.startPrank(alice);

        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        validator.epochEnd(); 
    }

    function test_EpochEnd_Reverts_When_RewardPool_Became_0() public {
        // 1. Lock licenses
        vm.startPrank(alice);
        for (uint256 i = 0; i < 6; i++) {
            validator.lockLicense(i);
        }
        vm.stopPrank();
    
        vm.startPrank(admin);
        vm.warp(validator.lastEpochTime() + 10 minutes);
    
        for (uint256 i = 0; i < 50; i++) {
            validator.epochEnd();
            vm.warp(validator.lastEpochTime() + 10 minutes);
        }
        
        vm.expectRevert(
            IValidatorErrors.Validator_NoRewardsInPool.selector
        );
        validator.epochEnd();
    }

    function test_EpochEnd_Reverts_When_Owner_Calls_It_Before_Epoch_Elapsed() public {
        // 1. Lock licenses
        vm.startPrank(alice);
        for (uint256 i = 0; i < 6; i++) {
            validator.lockLicense(i);
        }
        vm.stopPrank();
    
        vm.startPrank(admin);
        vm.expectRevert(
            IValidatorErrors.Validator_EpochNotFinishedYet.selector
        );
        validator.epochEnd();   // unlock when time didn't elapsed yet
    }
    
    
    
    /*//////////////////////////////////////////////////
                claimRewards() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_Validator_Successfully_Claim_Rewards_At_Any_Time() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        vm.startPrank(alice);
        for (uint256 i = 0; i < 6; i++) {
            validator.lockLicense(i);
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected alice reward for epoch 1.
        (uint256 expectedAliceRewardsPerEpoch1,,) = calculateExpectedRewards();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();    // contract owner calling this function which closes current epoch, distributes rewards and calculate rewards pool for next epoch 2
        
        /////////////////////////////////// 2nd epoch ////////////////////////////////////////

        // 5. Claim rewards.
        vm.startPrank(alice);
        validator.claimRewards();

        // 6. Get alice updated balances for verification.
        uint256 aliceRewardTokenBalance = rewardToken.balanceOf(alice);
        uint256 aliceAvailableBalanceForClaim = validator.validatorRewards(alice);

        assertEq(aliceRewardTokenBalance, expectedAliceRewardsPerEpoch1); // checking rewards per epoch 1, because alice claimed only for this epoch
        assertEq(aliceAvailableBalanceForClaim, 0);
    }

    function test_ClaimRewards_Reverts_If_Validator_Have_No_Rewards() public {
        vm.startPrank(alice);

        vm.expectRevert(
            IValidatorErrors.Validator_NoRewardsToClaim.selector
        );
        validator.claimRewards();
    }

    function test_ClaimRewards_Reverts_If_Contract_Is_On_Pause() public {
        /////////////////////////////////// 1st epoch ////////////////////////////////////////
        // 1. Lock licenses.
        vm.startPrank(alice);
        for (uint256 i = 0; i < 6; i++) {
            validator.lockLicense(i);
        }

        // 2. Move time forward to be able to finish epoch 1.
        vm.warp(validator.lastEpochTime() + 10 minutes);   // simulate epoch finishing 

        // 3. Get expected alice reward for epoch 1.
        (uint256 expectedAliceRewardsPerEpoch1,,) = calculateExpectedRewards();

        // 4. Close epoch, distribute rewards to validators, and decrease total rewards pool for future epoch.
        vm.startPrank(admin);
        validator.epochEnd();    

        /////////////////////////////////// 2nd epoch ////////////////////////////////////////
        // 5. Owner put the contract on pause.
        validator.pauseContract();

        vm.startPrank(alice);
        
        vm.expectRevert(
            Pausable.EnforcedPause.selector
        );
        validator.claimRewards();

        uint256 aliceRewardTokenBalance = rewardToken.balanceOf(alice);
        uint256 aliceAvailableBalanceForClaim = validator.validatorRewards(alice);

        assertEq(aliceRewardTokenBalance, 0); // no rewards were withdrawn due to the pause
        assertEq(aliceAvailableBalanceForClaim, expectedAliceRewardsPerEpoch1); // balance didn't change due to the pause
    }


    /*//////////////////////////////////////////////////
            onERC721Received() FUNCTION TESTS
    /////////////////////////////////////////////////*/
    function test_onERC721Received_Returns_Correct_Selector() public {
        bytes4 expectedSelector = validator.onERC721Received.selector;
        
        vm.startPrank(address(licenseToken));
        bytes4 actualSelector = validator.onERC721Received(
            address(this),
            alice,
            0,
            ""
        );

        assertEq(actualSelector, expectedSelector);
    }

    function test_OnERC721Received_Reverts_When_Called_Not_By_LicenseToken() public {
        // Create a mock caller address that's different from licenseToken
        address mockCaller = makeAddr("mockCaller");
        
        vm.startPrank(mockCaller);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                IValidatorErrors.Validator_CanOnlyBeCalledByLicenseTokenContract.selector,
                mockCaller
            )
        );
        
        validator.onERC721Received(
            address(this),
            alice,
            0,
            ""
        );
    }
}