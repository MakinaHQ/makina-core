// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
// import {AcrossV3BridgeAdapter} from "../../src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {LayerZeroV2BridgeAdapter} from "../../src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
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
        address beacon = 0xD8AF4c91Ddf2D640c6748050e3D8ecCa39A84563;
        address coreRegistry = 0x19b3161c7c25c94Da0A3f79Ee2E9407f02a85bAC;
        address layerZeroV2Endpoint = 0x3A73033C0b1407574C76BdBAc67f126f6b4a9AA9;

        console.log("Beacon         :", beacon);
        console.log("Current impl   :", UpgradeableBeacon(beacon).implementation());

        // vm.startBroadcast();

        // // Deploy new implementation with updated addresses
        // LayerZeroV2BridgeAdapter newImpl = new LayerZeroV2BridgeAdapter(
        //     coreRegistry,
        //     layerZeroV2Endpoint
        // );

        // // Point beacon to new impl — all proxies upgrade atomically
        // UpgradeableBeacon(beacon).upgradeTo(address(newImpl));

        // vm.stopBroadcast();

        bytes memory cd = abi.encodeCall(UpgradeableBeacon.upgradeTo, (0x3C1fD0A437Ba6D7D431cADeFc11f69137e9BA39f));

        // console.log("New impl       :", address(newImpl));
        console.logBytes(cd);
    }
}
