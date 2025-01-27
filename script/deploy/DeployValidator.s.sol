// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {Validator} from  "../../src/Validator.sol";
import {HelperConfig} from "../HelperConfig.s.sol";


contract DeployValidator is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (Validator, HelperConfig.NetworkConfig memory) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid);
        
        vm.startBroadcast(config.adminPk);
        Validator validator = new Validator(
            config.epochDuration,
            config.rewardDecayRate,
            config.initialRewards,
            config.licenseToken,
            config.rewardToken
        );
        vm.stopBroadcast();

        console.log("Validator contract deployed at: ", address(validator));

        return (validator, config);
    }
}