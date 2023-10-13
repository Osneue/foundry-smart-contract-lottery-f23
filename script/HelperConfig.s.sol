// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mock/LinkenTokenMock.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        uint256 fee;
        uint256 interval;
        uint64 subscriptionId;
        address coordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        address linkToken;
        uint256 deployKey;
    }

    uint256 private constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 private constant GANACHE_CHAIN_ID = 1337;
    uint256 private constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    NetworkConfig private s_activeNetworkConfig;

    function getNetworkConfig() external returns (NetworkConfig memory) {
        if (block.chainid == SEPOLIA_CHAIN_ID) {
            return getSepoliaNetworkConfig();
        } else if (block.chainid == GANACHE_CHAIN_ID) {
            return createAndGetGanacheNetworkConfig();
        } else {
            return createAndGetAnvilNetworkConfig();
        }
    }

    function getSepoliaNetworkConfig() private view returns (NetworkConfig memory) {
        NetworkConfig memory config = NetworkConfig({
            fee: 0.001 ether,
            interval: 30,
            subscriptionId: 5843,
            coordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625,
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            deployKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });
        return config;
    }

    function createAndGetAnvilNetworkConfig() private returns (NetworkConfig memory) {
        if (s_activeNetworkConfig.coordinator != address(0)) {
            return s_activeNetworkConfig;
        }

        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock coordinator = new VRFCoordinatorV2Mock(
            0.001 ether,
            1 gwei
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory config = NetworkConfig({
            fee: 0.001 ether,
            interval: 30,
            subscriptionId: 0, // defaults to zero, and it will create on Anvil promgramatically
            coordinator: address(coordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            deployKey: ANVIL_PRIVATE_KEY
        });

        s_activeNetworkConfig = config;

        return config;
    }

    function createAndGetGanacheNetworkConfig() private returns (NetworkConfig memory) {
        if (s_activeNetworkConfig.coordinator != address(0)) {
            return s_activeNetworkConfig;
        }

        uint256 deployKey = vm.envUint("GANACHE_PRIVATE_KEY");

        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock coordinator = new VRFCoordinatorV2Mock(
            0.001 ether,
            1 gwei
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        NetworkConfig memory config = NetworkConfig({
            fee: 0.001 ether,
            interval: 30,
            subscriptionId: 0, // defaults to zero, and it will create on Anvil promgramatically
            coordinator: address(coordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            linkToken: address(linkToken),
            deployKey: deployKey
        });

        s_activeNetworkConfig = config;

        return config;
    }
}
