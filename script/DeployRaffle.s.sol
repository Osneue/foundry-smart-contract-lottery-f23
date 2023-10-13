// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interaction.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getNetworkConfig();

        if (networkConfig.subscriptionId == 0) {
            // Create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            networkConfig.subscriptionId =
                createSubscription.createSubscription(networkConfig.coordinator, networkConfig.deployKey);

            // Fund subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundScription(
                networkConfig.linkToken,
                networkConfig.coordinator,
                networkConfig.subscriptionId,
                networkConfig.deployKey
            );
        }

        vm.startBroadcast(networkConfig.deployKey);
        Raffle raffle = new Raffle(
            networkConfig.fee,
            networkConfig.interval,
            networkConfig.subscriptionId,
            networkConfig.coordinator,
            networkConfig.gasLane,
            networkConfig.callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            networkConfig.coordinator, networkConfig.subscriptionId, address(raffle), networkConfig.deployKey
        );

        return (raffle, helperConfig);
    }
}
