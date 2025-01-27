// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LicenseToken} from  "../../src/LicenseToken.sol";

contract DeployLicenseToken is Script {
    function run() public {
        deploy();
    }

    function deploy() public returns (LicenseToken) {
        vm.startBroadcast();
        LicenseToken token = new LicenseToken();
        vm.stopBroadcast();

        console.log("License token contract deployed at: ", address(token));

        return token;
    }
}