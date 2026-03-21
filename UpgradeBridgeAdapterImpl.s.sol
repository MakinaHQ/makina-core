// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {AcrossV3BridgeAdapter} from "../src/bridge/adapters/AcrossV3BridgeAdapter.sol";

/**
 * @title  UpgradeBridgeAdapterImpl
 * @notice Deploys a fresh AcrossV3BridgeAdapter with updated constructor
 *         addresses and points the beacon to it.
 *
 *   forge script script/UpgradeBridgeAdapterImpl.s.sol \
 *       --rpc-url $RPC_URL \
 *       --broadcast --verify \
 *       --private-key $PRIVATE_KEY \
 *       --etherscan-api-key $ETHERSCAN_API_KEY \
 *       -vvvv
 */
contract UpgradeBridgeAdapterImpl is Script {
    function run() external {
        // ── Config (set in .env or hardcode) ────────────────────────────
        address beacon = vm.envAddress("BRIDGE_ADAPTER_BEACON");

        // Update these with the new addresses you need:
        // address newSpokePool   = vm.envAddress("ACROSS_SPOKE_POOL");
        // address newSomething   = vm.envAddress("...");
        // ... whatever constructor args AcrossV3BridgeAdapter takes

        console.log("Beacon         :", beacon);
        console.log("Current impl   :", UpgradeableBeacon(beacon).implementation());

        vm.startBroadcast();

        // Deploy new implementation with updated addresses
        AcrossV3BridgeAdapter newImpl = new AcrossV3BridgeAdapter(
            // pass your updated constructor args here, e.g.:
            // newSpokePool
        );

        // Point beacon to new impl — all proxies upgrade atomically
        UpgradeableBeacon(beacon).upgradeTo(address(newImpl));

        vm.stopBroadcast();

        console.log("New impl       :", address(newImpl));
    }
}
