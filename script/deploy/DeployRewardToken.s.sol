// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {RewardToken} from  "../../src/RewardToken.sol";
import {HelperConfig} from "../HelperConfig.s.sol";


contract DeployRewardToken is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (RewardToken) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid, false);

        vm.startBroadcast(config.adminPk);
        RewardToken token = new RewardToken();
        vm.stopBroadcast();

        console.log("Reward token contract deployed at: ", address(token));

        return token;
    }
}