// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {LicenseToken} from "../src/LicenseToken.sol";
import {RewardToken} from "../src/RewardToken.sol";
import {IHelperConfigErrors} from "../src/interfaces/utils/ICustomErrors.sol";

abstract contract Constants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 80002;
    uint256 public constant TN_ETH_MAINNET_FORK_CHAIN_ID = 25112000; // please set up here your custom chain id from Tenderly virtual network
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, Constants, IHelperConfigErrors {
    struct NetworkConfig {
        uint256 adminPk;
        uint256 epochDuration;
        uint256 rewardDecayRate;
        uint256 initialRewards;
        address licenseToken;
        address rewardToken;
    }

    /**
     * @dev Allows to receive a config for deployment/tests/scripts based on the chain you are.
     * 
     * @param _chainId - id of your chain you are working on.
     * 
     * @return `NetworkConfig` structure is returned.
     */
    function getConfigByChainId(uint256 _chainId) public returns (NetworkConfig memory) {
        if (_chainId == LOCAL_CHAIN_ID) {
            return getLocalNetworkConfig();
        } else if (_chainId == TN_ETH_MAINNET_FORK_CHAIN_ID) {
            return getEthMainnetForkNetworkConfig();
        } else if (_chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getEthSepoliaNetworkConfig();
        } else {
            revert HelperConfig_NonSupportedChain();
        }
    }

    /**
     * @dev Returns a config with necessary parameters for local deployment/interraction/testing.
     * Instructions:
     *  -
     * 
     * @return `NetworkConfig` structure is returned.
     */
    function getLocalNetworkConfig() public returns (NetworkConfig memory) {
        vm.startBroadcast(vm.envUint("LOCAL_ADMIN_PK"));
        LicenseToken lsToken = new LicenseToken();
        RewardToken rwToken = new RewardToken();
        vm.stopBroadcast();
        
        NetworkConfig memory localNetworkConfig = NetworkConfig({
            adminPk: vm.envUint("LOCAL_ADMIN_PK"), // pk from anvil list
            epochDuration: 10 minutes,             // 10 min duration of each epoch
            rewardDecayRate: 10,                   // 10% decay rate in each new epoch
            initialRewards: 1000,                  // initial rewards starting from 1000 in 1st epoch
            licenseToken: address(lsToken),  
            rewardToken: address(rwToken)
        });

        return localNetworkConfig;
    }

    /**
     * @dev Returns a config with necessary parameters for Tenderly fork network deployment/interraction/testing.
     * Instructions:
     *  - 
     * 
     * @return `NetworkConfig` structure is returned.
     */
    function getEthMainnetForkNetworkConfig() public view returns(NetworkConfig memory) {
    }

    /**
     * @dev Returns a config with necessary parameters for Amoy testnet deployment/interraction/testing.
     * Instructions:
     *  -
     * 
     * @return `NetworkConfig` structure is returned.
     */
    function getEthSepoliaNetworkConfig() public view returns(NetworkConfig memory) {
    }
}