// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LicenseToken} from  "../../src/LicenseToken.sol";
import {HelperConfig} from "../HelperConfig.s.sol";


contract DeployLicenseToken is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (LicenseToken) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfigByChainId(block.chainid, false);

        vm.startBroadcast(config.adminPk);
        LicenseToken token = new LicenseToken();
        vm.stopBroadcast();

        console.log("License token contract deployed at: ", address(token));

        return token;
    }
}