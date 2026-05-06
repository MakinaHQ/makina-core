// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {UpgradeCore} from "./UpgradeCore.s.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";
import {AcrossV3BridgeAdapter} from "../../src/bridge/adapters/AcrossV3BridgeAdapter.sol";
import {AcrossV3BridgeConfig} from "../../src/bridge/configs/AcrossV3BridgeConfig.sol";
import {LayerZeroV2BridgeAdapter} from "../../src/bridge/adapters/LayerZeroV2BridgeAdapter.sol";
import {LayerZeroV2BridgeConfig} from "../../src/bridge/configs/LayerZeroV2BridgeConfig.sol";
import {Caliber} from "../../src/caliber/Caliber.sol";
import {CaliberMailbox} from "../../src/caliber/CaliberMailbox.sol";
import {OracleRegistry} from "../../src/registries/OracleRegistry.sol";
import {SpokeCoreRegistry} from "../../src/registries/SpokeCoreRegistry.sol";
import {SpokeCoreFactory} from "../../src/factories/SpokeCoreFactory.sol";
import {SwapModule} from "../../src/swap/SwapModule.sol";
import {TokenRegistry} from "../../src/registries/TokenRegistry.sol";

contract UpgradeSpokeCore is UpgradeCore {
    using stdJson for string;

    struct SpokeCore {
        address accessManager;
        address oracleRegistry;
        address swapModule;
        address tokenRegistry;
        address spokeCoreRegistry;
        address spokeCoreFactory;
        address weirollVM;
        address caliberBeacon;
        address caliberMailboxBeacon;
        address acrossV3BridgeAdapterBeacon;
        address acrossV3BridgeConfig;
        address layerZeroV2BridgeAdapterBeacon;
        address layerZeroV2BridgeConfig;
        address cctpV2BridgeAdapterBeacon;
        address cctpV2BridgeConfig;
    }

    struct SpokeCoreImplems {
        address accessManager;
        address oracleRegistry;
        address swapModule;
        address tokenRegistry;
        address spokeCoreRegistry;
        address spokeCoreFactory;
        address caliber;
        address caliberMailbox;
        address acrossV3BridgeAdapter;
        address acrossV3BridgeConfig;
        address layerZeroV2BridgeAdapter;
        address layerZeroV2BridgeConfig;
    }

    // BASE PROD ADDRESSES
    address BASE_acrossV3SpokePool = 0x09aea4b2242abC8bb4BB78D537A67a245A7bEC64;
    address BASE_layerZeroV2Endpoint = 0x1a44076050125825900e736c501f859c50fE728c;

    // ARBITRUM PROD ADDRESSES
    address ARBITRUM_acrossV3SpokePool = 0xe35e9842fceaCA96570B734083f4a58e8F7C5f2A;
    address ARBITRUM_layerZeroV2Endpoint = 0x1a44076050125825900e736c501f859c50fE728c;

    // OPTIMISM PROD ADDRESSES
    address OPTIMISM_acrossV3SpokePool = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address OPTIMISM_layerZeroV2Endpoint = 0x1a44076050125825900e736c501f859c50fE728c;

    // INK PROD ADDRESSES
    address INK_acrossV3SpokePool = 0xeF684C38F94F48775959ECf2012D7E864ffb9dd4;
    address INK_layerZeroV2Endpoint = 0xca29f3A6f966Cb2fc0dE625F8f325c0C46dbE958;

    // MONAD PROD ADDRESSES
    address MONAD_layerZeroV2Endpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;

    function _coreSetup() public override {
        address acrossV3SpokePool = INK_acrossV3SpokePool;
        address layerZeroV2Endpoint = INK_layerZeroV2Endpoint;

        uint256 hubChainId = 1;
        SpokeCore memory spokeCore = SpokeCore({
            accessManager: 0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F,
            oracleRegistry: 0xC388B72AB90Be82B230D919F9C05c87F9397f485,
            swapModule: 0x923c98b22F9c367A109E93f7dfBaCa28b20C17C3,
            tokenRegistry: 0xd9310A41d085c0DC1E40F691e8647080862A5fd4,
            spokeCoreRegistry: 0x0FAEeCEab0BCb63bE2Fe984Ea8c77778989d53eA,
            spokeCoreFactory: 0x8d28A69328561eF9F171c58996fEcB9F494e070c,
            weirollVM: 0xFD162A672928bf40E5A81F0D11501D2849841FA6,
            caliberBeacon: 0x3f5A881DB86D6f495823028A1e892E7b2CD7e162,
            caliberMailboxBeacon: 0x2f7101C2EFfa4a2d48A95958F594e3306717a0A0,
            acrossV3BridgeAdapterBeacon: 0x511C3F33417275d060932458DD987bd47c9ca678,
            acrossV3BridgeConfig: 0xDdE7FD6f25c9a58c5ec3E278d31e8584f236da86,
            layerZeroV2BridgeAdapterBeacon: 0x1108204c18FCB5e0b2b38Cbd3B783b2A56B42467,
            layerZeroV2BridgeConfig: 0x1B064336D9C4999C942Ecc36e36d48a411343771,
            cctpV2BridgeAdapterBeacon: 0xFD58f8e3569197677CEEB6AaFEb8147b715513CC,
            cctpV2BridgeConfig: 0x1be75B412cc8bE1bf64A84D40322dD889cfD6134
        });

        // set to address(0) if upgrade-permissioned address is not a TimelockController instance.
        address proxyUpgradeTimelock = 0x3BB482503d2d086126D5ABCbF7D6144937Abe107;

        // DEPLOY NEW IMPLEMS
        SpokeCoreImplems memory spokeCoreImplems;

        // spokeCoreImplems.accessManager = _deployCode(type(AccessManagerUpgradeable).creationCode, 0);
        // console.log("AccessManagerUpgradeable implem:", spokeCoreImplems.accessManager);

        spokeCoreImplems.oracleRegistry = _deployCode(type(OracleRegistry).creationCode, 0);
        console.log("OracleRegistry implem:", spokeCoreImplems.oracleRegistry);

        spokeCoreImplems.tokenRegistry = _deployCode(type(TokenRegistry).creationCode, 0);
        console.log("TokenRegistry implem:", spokeCoreImplems.tokenRegistry);

        spokeCoreImplems.spokeCoreRegistry = _deployCode(type(SpokeCoreRegistry).creationCode, 0);
        console.log("SpokeCoreRegistry implem:", spokeCoreImplems.spokeCoreRegistry);

        spokeCoreImplems.spokeCoreFactory = _deployCode(
            abi.encodePacked(type(SpokeCoreFactory).creationCode, abi.encode(spokeCore.spokeCoreRegistry)), 0
        );
        console.log("SpokeCoreFactory implem:", spokeCoreImplems.spokeCoreFactory);

        spokeCoreImplems.swapModule =
            _deployCode(abi.encodePacked(type(SwapModule).creationCode, abi.encode(spokeCore.spokeCoreRegistry)), 0);
        console.log("SwapModule implem:", spokeCoreImplems.swapModule);

        spokeCoreImplems.caliber = _deployCode(
            abi.encodePacked(type(Caliber).creationCode, abi.encode(spokeCore.spokeCoreRegistry, spokeCore.weirollVM)),
            0
        );
        console.log("Caliber implem:", spokeCoreImplems.caliber);

        spokeCoreImplems.caliberMailbox = _deployCode(
            abi.encodePacked(type(CaliberMailbox).creationCode, abi.encode(spokeCore.spokeCoreRegistry, hubChainId)), 0
        );
        console.log("CaliberMailbox implem:", spokeCoreImplems.caliberMailbox);

        spokeCoreImplems.acrossV3BridgeAdapter = _deployCode(
            abi.encodePacked(
                type(AcrossV3BridgeAdapter).creationCode, abi.encode(spokeCore.spokeCoreRegistry, acrossV3SpokePool)
            ),
            0
        );
        console.log("AcrossV3BridgeAdapter implem:", spokeCoreImplems.acrossV3BridgeAdapter);

        spokeCoreImplems.acrossV3BridgeConfig = _deployCode(type(AcrossV3BridgeConfig).creationCode, 0);
        console.log("AcrossV3BridgeConfig implem:", spokeCoreImplems.acrossV3BridgeConfig);

        spokeCoreImplems.layerZeroV2BridgeAdapter = _deployCode(
            abi.encodePacked(
                type(LayerZeroV2BridgeAdapter).creationCode,
                abi.encode(spokeCore.spokeCoreRegistry, layerZeroV2Endpoint)
            ),
            0
        );
        console.log("LayerZeroV2BridgeAdapter implem:", spokeCoreImplems.layerZeroV2BridgeAdapter);

        spokeCoreImplems.layerZeroV2BridgeConfig = _deployCode(type(LayerZeroV2BridgeConfig).creationCode, 0);
        console.log("LayerZeroV2BridgeConfig implem:", spokeCoreImplems.layerZeroV2BridgeConfig);

        // UPGRADE PROXIES AND BEACONS

        // console.log("\n", "== Upgrade AccessManager ==");
        // _upgradeTransparentProxy(
        //     address(spokeCore.accessManager), spokeCoreImplems.accessManager, true, proxyUpgradeTimelock
        // );

        console.log("\n", "== Upgrade OracleRegistry ==");
        _upgradeTransparentProxy(
            address(spokeCore.oracleRegistry), spokeCoreImplems.oracleRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade TokenRegistry ==");
        _upgradeTransparentProxy(
            address(spokeCore.tokenRegistry), spokeCoreImplems.tokenRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade SpokeCoreRegistry ==");
        _upgradeTransparentProxy(
            address(spokeCore.spokeCoreRegistry), spokeCoreImplems.spokeCoreRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade SpokeCoreFactory ==");
        _upgradeTransparentProxy(
            address(spokeCore.spokeCoreFactory), spokeCoreImplems.spokeCoreFactory, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade SwapModule ==");
        _upgradeTransparentProxy(address(spokeCore.swapModule), spokeCoreImplems.swapModule, true, proxyUpgradeTimelock);

        console.log("\n", "== Upgrade Caliber Beacon ==");
        _upgradeBeaconProxy(address(spokeCore.caliberBeacon), spokeCoreImplems.caliber, true, proxyUpgradeTimelock);

        console.log("\n", "== Upgrade CaliberMailbox Beacon ==");
        _upgradeBeaconProxy(
            address(spokeCore.caliberMailboxBeacon), spokeCoreImplems.caliberMailbox, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade AcrossV3BridgeAdapter Beacon ==");
        _upgradeBeaconProxy(
            address(spokeCore.acrossV3BridgeAdapterBeacon),
            spokeCoreImplems.acrossV3BridgeAdapter,
            true,
            proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade AcrossV3BridgeConfig ==");
        _upgradeTransparentProxy(
            address(spokeCore.acrossV3BridgeConfig), spokeCoreImplems.acrossV3BridgeConfig, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade LayerZeroV2BridgeAdapter Beacon ==");
        _upgradeBeaconProxy(
            address(spokeCore.layerZeroV2BridgeAdapterBeacon),
            spokeCoreImplems.layerZeroV2BridgeAdapter,
            true,
            proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade LayerZeroV2BridgeConfig ==");
        _upgradeTransparentProxy(
            address(spokeCore.layerZeroV2BridgeConfig),
            spokeCoreImplems.layerZeroV2BridgeConfig,
            true,
            proxyUpgradeTimelock
        );

        console.log("\n", "== Register CctpV2BridgeAdapter Beacon ==");
        console.log("Core registry:", spokeCore.spokeCoreRegistry);
        console.logBytes(abi.encodeCall(ICoreRegistry.setBridgeAdapterBeacon, (3, spokeCore.cctpV2BridgeAdapterBeacon)));

        console.log("\n", "== Register CctpV2BridgeConfig ==");
        console.log("Core registry:", spokeCore.spokeCoreRegistry);
        console.logBytes(abi.encodeCall(ICoreRegistry.setBridgeConfig, (3, spokeCore.cctpV2BridgeConfig)));

        // AM updates for each new function + those which sig was modified
        // if (!vm.envOr("SKIP_AM_SETUP", false)) {
        //     setupSpokeCoreAMFunctionRoles(_core);
        // }
    }
}
