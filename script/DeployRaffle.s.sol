// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {AddConsumer, CreateSubscription, FundSubscription} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    function run() external returns (Raffle, HelperConfig) {
        console.log("Starting DeployRaffle script...");

        HelperConfig helperConfig = new HelperConfig();
        console.log("HelperConfig instance created.");

        AddConsumer addConsumer = new AddConsumer();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        console.log("HelperConfig active network config retrieved.");

        if (config.subscriptionId == 0) {
            console.log("Creating subscription...");
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinatorV2_5) =
                createSubscription.createSubscription(config.vrfCoordinatorV2_5, config.account);
            console.log("Subscription created with ID:", config.subscriptionId);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinatorV2_5, config.subscriptionId, config.link, config.account
            );
            console.log("Subscription funded.");

            helperConfig.setConfig(block.chainid, config);
            console.log("HelperConfig updated with new subscription.");
        }

        console.log("Starting broadcast...");
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.subscriptionId,
            config.gasLane,
            config.interval,
            config.raffleEntranceFee,
            config.callbackGasLimit,
            config.vrfCoordinatorV2_5
        );
        console.log("Raffle contract deployed at:", address(raffle));
        vm.stopBroadcast();
        console.log("Broadcast stopped.");

        console.log("Adding consumer on contract:", address(raffle));
        console.log("Using vrfCoordinator:", config.vrfCoordinatorV2_5);
        console.log("Subscription ID:", config.subscriptionId);
        console.log("on ChainID", block.chainid);
        addConsumer.addConsumer(address(raffle), config.vrfCoordinatorV2_5, config.subscriptionId, config.account);
        console.log("Raffle contract added as consumer.");

        return (raffle, helperConfig);
    }
}
