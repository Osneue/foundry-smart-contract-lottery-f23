// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "test/mock/LinkenTokenMock.sol";

contract CreateSubscription is Script {
    uint256 private constant ANVIL_CHAIN_ID = 31337;
    uint256 private constant GANACHE_CHAIN_ID = 1337;

    function createSubscription(address coordinator, uint256 key) external returns (uint64) {
        if (block.chainid == ANVIL_CHAIN_ID || block.chainid == GANACHE_CHAIN_ID) {
            vm.startBroadcast(key);
            uint64 subscriptionId = VRFCoordinatorV2Mock(coordinator).createSubscription();
            vm.stopBroadcast();
            return subscriptionId;
        } else {
            vm.startBroadcast(key);
            uint64 subscriptionId = VRFCoordinatorV2Interface(coordinator).createSubscription();
            vm.stopBroadcast();
            return subscriptionId;
        }
    }

    function run() external returns (uint64) {}
}

contract FundSubscription is Script {
    uint96 private constant LINK_AMOUNT = 1 ether;
    uint256 private constant ANVIL_CHAIN_ID = 31337;
    uint256 private constant GANACHE_CHAIN_ID = 1337;

    function fundScription(address linkToken, address coordinator, uint64 subscriptionId, uint256 key) public {
        if (block.chainid == ANVIL_CHAIN_ID || block.chainid == GANACHE_CHAIN_ID) {
            vm.startBroadcast(key);
            VRFCoordinatorV2Mock(coordinator).fundSubscription(subscriptionId, LINK_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(key);
            LinkToken(linkToken).transferAndCall(coordinator, LINK_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function fundScriptionWithNetworkConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();
        fundScription(
            networkConfig.linkToken, networkConfig.coordinator, networkConfig.subscriptionId, networkConfig.deployKey
        );
    }

    function run() external {
        fundScriptionWithNetworkConfig();
    }
}

contract AddConsumer is Script {
    uint96 private constant LINK_AMOUNT = 100 ether;
    uint256 private constant ANVIL_CHAIN_ID = 31337;
    uint256 private constant GANACHE_CHAIN_ID = 1337;

    function addConsumer(address coordinator, uint64 subscriptionId, address consumer, uint256 key) external {
        if (block.chainid == ANVIL_CHAIN_ID || block.chainid == GANACHE_CHAIN_ID) {
            vm.startBroadcast(key);
            VRFCoordinatorV2Mock(coordinator).addConsumer(subscriptionId, consumer);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(key);
            VRFCoordinatorV2Interface(coordinator).addConsumer(subscriptionId, consumer);
            vm.stopBroadcast();
        }
    }

    function run() external {}
}
