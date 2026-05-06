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
import {ChainRegistry} from "../../src/registries/ChainRegistry.sol";
import {HubCoreRegistry} from "../../src/registries/HubCoreRegistry.sol";
import {Machine} from "../../src/machine/Machine.sol";
import {HubCoreFactory} from "../../src/factories/HubCoreFactory.sol";
import {OracleRegistry} from "../../src/registries/OracleRegistry.sol";
import {PreDepositVault} from "../../src/pre-deposit/PreDepositVault.sol";
import {SwapModule} from "../../src/swap/SwapModule.sol";
import {TokenRegistry} from "../../src/registries/TokenRegistry.sol";

contract UpgradeHubCore is UpgradeCore {
    using stdJson for string;

    struct HubCore {
        address accessManager;
        address oracleRegistry;
        address swapModule;
        address tokenRegistry;
        address chainRegistry;
        address hubCoreRegistry;
        address hubCoreFactory;
        address weirollVM;
        address caliberBeacon;
        address machineBeacon;
        address preDepositVaultBeacon;
        address acrossV3BridgeAdapterBeacon;
        address acrossV3BridgeConfig;
        address layerZeroV2BridgeAdapterBeacon;
        address layerZeroV2BridgeConfig;
        address cctpV2BridgeAdapterBeacon;
        address cctpV2BridgeConfig;
    }

    struct HubCoreImplems {
        address accessManager;
        address oracleRegistry;
        address swapModule;
        address tokenRegistry;
        address chainRegistry;
        address hubCoreRegistry;
        address hubCoreFactory;
        address caliber;
        address machine;
        address preDepositVault;
        address acrossV3BridgeAdapter;
        address acrossV3BridgeConfig;
        address layerZeroV2BridgeAdapter;
        address layerZeroV2BridgeConfig;
    }

    function _coreSetup() public override {
        // MAINNET PROD ADDRESSES
        address acrossV3SpokePool = 0x5c7BCd6E7De5423a257D81B442095A1a6ced35C5;
        address layerZeroV2Endpoint = 0x1a44076050125825900e736c501f859c50fE728c;

        address wormhole = 0x98f3c9e6E3fAce36bAAd05FE09d375Ef1464288B;

        HubCore memory hubCore = HubCore({
            accessManager: 0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F,
            oracleRegistry: 0xC388B72AB90Be82B230D919F9C05c87F9397f485,
            swapModule: 0x923c98b22F9c367A109E93f7dfBaCa28b20C17C3,
            tokenRegistry: 0xd9310A41d085c0DC1E40F691e8647080862A5fd4,
            chainRegistry: 0x45681FCf26EF1dCa89ae2B8B97c6447ea68771Df,
            hubCoreRegistry: 0x0FAEeCEab0BCb63bE2Fe984Ea8c77778989d53eA,
            hubCoreFactory: 0x8d28A69328561eF9F171c58996fEcB9F494e070c,
            weirollVM: 0xFD162A672928bf40E5A81F0D11501D2849841FA6,
            caliberBeacon: 0x3f5A881DB86D6f495823028A1e892E7b2CD7e162,
            machineBeacon: 0x5C680EC39bafE8524F3C2fa9d5F6D65F09Bd7333,
            preDepositVaultBeacon: 0x3793c81F3e0BA4BCf66C88baf266C039f14A54c1,
            acrossV3BridgeAdapterBeacon: 0x511C3F33417275d060932458DD987bd47c9ca678,
            acrossV3BridgeConfig: 0xDdE7FD6f25c9a58c5ec3E278d31e8584f236da86,
            layerZeroV2BridgeAdapterBeacon: 0x1108204c18FCB5e0b2b38Cbd3B783b2A56B42467,
            layerZeroV2BridgeConfig: 0x1B064336D9C4999C942Ecc36e36d48a411343771,
            cctpV2BridgeAdapterBeacon: 0xFD58f8e3569197677CEEB6AaFEb8147b715513CC,
            cctpV2BridgeConfig: 0x1be75B412cc8bE1bf64A84D40322dD889cfD6134
        });

        // set to address(0) if upgrade-permissioned address is not a TimelockController instance.
        address proxyUpgradeTimelock = 0xa113bE73B97753A81A63d2539809b90451F1EC56;

        // DEPLOY NEW IMPLEMS
        HubCoreImplems memory hubCoreImplems;

        hubCoreImplems.accessManager = _deployCode(type(AccessManagerUpgradeable).creationCode, 0);
        console.log("AccessManagerUpgradeable implem:", hubCoreImplems.accessManager);

        hubCoreImplems.oracleRegistry = _deployCode(type(OracleRegistry).creationCode, 0);
        console.log("OracleRegistry implem:", hubCoreImplems.oracleRegistry);

        hubCoreImplems.tokenRegistry = _deployCode(type(TokenRegistry).creationCode, 0);
        console.log("TokenRegistry implem:", hubCoreImplems.tokenRegistry);

        hubCoreImplems.chainRegistry = _deployCode(type(ChainRegistry).creationCode, 0);
        console.log("ChainRegistry implem:", hubCoreImplems.chainRegistry);

        hubCoreImplems.hubCoreRegistry = _deployCode(type(HubCoreRegistry).creationCode, 0);
        console.log("HubCoreRegistry implem:", hubCoreImplems.hubCoreRegistry);

        hubCoreImplems.hubCoreFactory =
            _deployCode(abi.encodePacked(type(HubCoreFactory).creationCode, abi.encode(hubCore.hubCoreRegistry)), 0);
        console.log("HubCoreFactory implem:", hubCoreImplems.hubCoreFactory);

        hubCoreImplems.swapModule =
            _deployCode(abi.encodePacked(type(SwapModule).creationCode, abi.encode(hubCore.hubCoreRegistry)), 0);
        console.log("SwapModule implem:", hubCoreImplems.swapModule);

        hubCoreImplems.caliber = _deployCode(
            abi.encodePacked(type(Caliber).creationCode, abi.encode(hubCore.hubCoreRegistry, hubCore.weirollVM)), 0
        );
        console.log("Caliber implem:", hubCoreImplems.caliber);

        hubCoreImplems.machine =
            _deployCode(abi.encodePacked(type(Machine).creationCode, abi.encode(hubCore.hubCoreRegistry, wormhole)), 0);
        console.log("Machine implem:", hubCoreImplems.machine);

        hubCoreImplems.preDepositVault =
            _deployCode(abi.encodePacked(type(PreDepositVault).creationCode, abi.encode(hubCore.hubCoreRegistry)), 0);
        console.log("PreDepositVault implem:", hubCoreImplems.preDepositVault);

        hubCoreImplems.acrossV3BridgeAdapter = _deployCode(
            abi.encodePacked(
                type(AcrossV3BridgeAdapter).creationCode, abi.encode(hubCore.hubCoreRegistry, acrossV3SpokePool)
            ),
            0
        );
        console.log("AcrossV3BridgeAdapter implem:", hubCoreImplems.acrossV3BridgeAdapter);

        hubCoreImplems.acrossV3BridgeConfig = _deployCode(type(AcrossV3BridgeConfig).creationCode, 0);
        console.log("AcrossV3BridgeConfig implem:", hubCoreImplems.acrossV3BridgeConfig);

        hubCoreImplems.layerZeroV2BridgeAdapter = _deployCode(
            abi.encodePacked(
                type(LayerZeroV2BridgeAdapter).creationCode, abi.encode(hubCore.hubCoreRegistry, layerZeroV2Endpoint)
            ),
            0
        );
        console.log("LayerZeroV2BridgeAdapter implem:", hubCoreImplems.layerZeroV2BridgeAdapter);

        hubCoreImplems.layerZeroV2BridgeConfig = _deployCode(type(LayerZeroV2BridgeConfig).creationCode, 0);
        console.log("LayerZeroV2BridgeConfig implem:", hubCoreImplems.layerZeroV2BridgeConfig);

        // UPGRADE PROXIES AND BEACONS
        console.log("\n", "== Upgrade AccessManager ==");
        _upgradeTransparentProxy(
            address(hubCore.accessManager), hubCoreImplems.accessManager, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade OracleRegistry ==");
        _upgradeTransparentProxy(
            address(hubCore.oracleRegistry), hubCoreImplems.oracleRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade TokenRegistry ==");
        _upgradeTransparentProxy(
            address(hubCore.tokenRegistry), hubCoreImplems.tokenRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade ChainRegistry ==");
        _upgradeTransparentProxy(
            address(hubCore.chainRegistry), hubCoreImplems.chainRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade HubCoreRegistry ==");
        _upgradeTransparentProxy(
            address(hubCore.hubCoreRegistry), hubCoreImplems.hubCoreRegistry, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade HubCoreFactory ==");
        _upgradeTransparentProxy(
            address(hubCore.hubCoreFactory), hubCoreImplems.hubCoreFactory, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade SwapModule ==");
        _upgradeTransparentProxy(address(hubCore.swapModule), hubCoreImplems.swapModule, true, proxyUpgradeTimelock);

        console.log("\n", "== Upgrade Caliber Beacon ==");
        _upgradeBeaconProxy(address(hubCore.caliberBeacon), hubCoreImplems.caliber, true, proxyUpgradeTimelock);

        console.log("\n", "== Upgrade Machine Beacon ==");
        _upgradeBeaconProxy(address(hubCore.machineBeacon), hubCoreImplems.machine, true, proxyUpgradeTimelock);

        console.log("\n", "== Upgrade PreDepositVault Beacon ==");
        _upgradeBeaconProxy(
            address(hubCore.preDepositVaultBeacon), hubCoreImplems.preDepositVault, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade AcrossV3BridgeAdapter Beacon ==");
        _upgradeBeaconProxy(
            address(hubCore.acrossV3BridgeAdapterBeacon),
            hubCoreImplems.acrossV3BridgeAdapter,
            true,
            proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade AcrossV3BridgeConfig ==");
        _upgradeTransparentProxy(
            address(hubCore.acrossV3BridgeConfig), hubCoreImplems.acrossV3BridgeConfig, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade LayerZeroV2BridgeAdapter Beacon ==");
        _upgradeBeaconProxy(
            address(hubCore.layerZeroV2BridgeAdapterBeacon),
            hubCoreImplems.layerZeroV2BridgeAdapter,
            true,
            proxyUpgradeTimelock
        );

        console.log("\n", "== Upgrade LayerZeroV2BridgeConfig ==");
        _upgradeTransparentProxy(
            address(hubCore.layerZeroV2BridgeConfig), hubCoreImplems.layerZeroV2BridgeConfig, true, proxyUpgradeTimelock
        );

        console.log("\n", "== Register CctpV2BridgeAdapter Beacon ==");
        console.log("Core registry:", hubCore.hubCoreRegistry);
        console.logBytes(abi.encodeCall(ICoreRegistry.setBridgeAdapterBeacon, (3, hubCore.cctpV2BridgeAdapterBeacon)));

        console.log("\n", "== Register CctpV2BridgeConfig ==");
        console.log("Core registry:", hubCore.hubCoreRegistry);
        console.logBytes(abi.encodeCall(ICoreRegistry.setBridgeConfig, (3, hubCore.cctpV2BridgeConfig)));

        // AM updates for each new function + those which sig was modified
        // if (!vm.envOr("SKIP_AM_SETUP", false)) {
        //     setupHubCoreAMFunctionRoles(_core);
        // }
    }
}
