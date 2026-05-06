// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployBridgeSetup is Base, Script, CreateXUtils {
    using stdJson for string;

    address public deployer;

    function run() public {
        address accessManager = 0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F;
        address coreRegistry = 0x0FAEeCEab0BCb63bE2Fe984Ea8c77778989d53eA;

        address CCTP_V2_TOKEN_MESSENGER = 0x28b5a0e9C621a5BadaA536219b3a228C8168cf5d;
        address CCTP_V2_MESSAGE_TRANSMITTER = 0x81D40F21F12A8F0E3252Bccb954D722d4c464B64;

        BridgeData memory bridgeData = BridgeData({
            bridgeId: CCTP_V2_BRIDGE_ID,
            approvalTarget: address(0),
            executionTarget: CCTP_V2_TOKEN_MESSENGER,
            receiveSource: CCTP_V2_MESSAGE_TRANSMITTER
        });

        // start broadcasting transactions
        vm.startBroadcast();

        (address _bridgeAdapterBeacon, address _bridgeConfig) =
            deployAndSetupBridges(accessManager, coreRegistry, bridgeData);

        vm.stopBroadcast();

        console.log("Deployed Bridge Adapter Beacon at: ", address(_bridgeAdapterBeacon));
        console.log("Deployed Bridge Config at: ", address(_bridgeConfig));
    }

    function deployAndSetupBridges(address accessManager, address coreRegistry, BridgeData memory bridgeData)
        internal
        returns (address bridgeAdapterBeacon, address bridgeConfig)
    {
        uint16 bridgeId = bridgeData.bridgeId;
        if (bridgeId == ACROSS_V3_BRIDGE_ID) {
            bridgeAdapterBeacon =
                address(_deployAcrossV3BridgeAdapterBeacon(accessManager, coreRegistry, bridgeData.executionTarget));
            bridgeConfig = address(_deployAcrossV3BridgeConfig(accessManager, accessManager));
        } else if (bridgeId == LAYER_ZERO_V2_BRIDGE_ID) {
            bridgeAdapterBeacon =
                address(_deployLayerZeroV2BridgeAdapterBeacon(accessManager, coreRegistry, bridgeData.receiveSource));
            bridgeConfig = payable(address(_deployLayerZeroV2BridgeConfig(accessManager, accessManager)));
        } else if (bridgeId == CCTP_V2_BRIDGE_ID) {
            bridgeAdapterBeacon = address(
                _deployCctpV2BridgeAdapterBeacon(
                    accessManager, coreRegistry, bridgeData.executionTarget, bridgeData.receiveSource
                )
            );
            bridgeConfig = address(_deployCctpV2BridgeConfig(accessManager, accessManager));
        } else {
            revert("Bridge not supported");
        }
    }

    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address) {
        return _deployCodeCreateX(bytecode, salt, deployer);
    }
}
