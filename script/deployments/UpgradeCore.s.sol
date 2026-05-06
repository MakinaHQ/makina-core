// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {ICoreRegistry} from "../../src/interfaces/ICoreRegistry.sol";

contract UpgradeCore is Script, CreateXUtils {
    using stdJson for string;

    address public deployer;

    function run() public {
        (, deployer,) = vm.readCallers();

        console.log("Deployer:", deployer);

        // start broadcasting transactions
        vm.startBroadcast(deployer);

        _coreSetup();
    }

    function _coreSetup() public virtual {}

    /// @dev Upgrades a given Transparent Proxy (ERC-1967) with the given implem contract
    function _upgradeTransparentProxy(address proxy, address newImplem, bool preview, address timelock) internal {
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address admin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));

        bytes memory cd =
            abi.encodeCall(ProxyAdmin.upgradeAndCall, (ITransparentUpgradeableProxy(proxy), newImplem, ""));

        bytes memory tscd;
        if (timelock != address(0)) {
            tscd = _wrapCdInTimelockScheduling(admin, cd, timelock);
        }

        if (preview) {
            console.log("ProxyAdmin:", admin);
            console.log("Upgrade CD:");
            console.logBytes(cd);
            if (timelock != address(0)) {
                console.log("Timelock schedule CD");
                console.logBytes(tscd);

                console.log("Timelock execute CD");
                console.logBytes(_wrapCdInTimelockExecution(admin, cd));
            }
        } else {
            bool success;
            if (timelock != address(0)) {
                (success,) = timelock.call(tscd);
            } else {
                (success,) = admin.call(cd);
            }
            require(success, "Upgrade failed");
        }
    }

    /// @dev Upgrades a given beacon with the given implem contract
    function _upgradeBeaconProxy(address beacon, address newImplem, bool preview, address timelock) internal {
        bytes memory cd = abi.encodeCall(UpgradeableBeacon.upgradeTo, (newImplem));

        bytes memory tscd;
        if (timelock != address(0)) {
            tscd = _wrapCdInTimelockScheduling(beacon, cd, timelock);
        }

        if (preview) {
            console.log("Beacon:", beacon);
            console.log("Upgrade CD:");
            console.logBytes(cd);
            if (timelock != address(0)) {
                console.log("Timelock schedule CD");
                console.logBytes(tscd);

                console.log("Timelock execute CD");
                console.logBytes(_wrapCdInTimelockExecution(beacon, cd));
            }
        } else {
            bool success;
            if (timelock != address(0)) {
                (success,) = timelock.call(tscd);
            } else {
                (success,) = beacon.call(cd);
            }
            require(success, "Upgrade failed");
        }
    }

    /// @dev Used only for implementation contracts here.
    function _deployCode(bytes memory bytecode, bytes32) internal returns (address) {
        return _deployCodeCreateX(bytecode, bytes32(0), deployer);
    }

    function _wrapCdInTimelockScheduling(address target, bytes memory cd, address timelock)
        internal
        view
        returns (bytes memory)
    {
        return abi.encodeCall(
            TimelockController.schedule,
            (target, 0, cd, bytes32(0), bytes32(0), TimelockController(payable(timelock)).getMinDelay())
        );
    }

    function _wrapCdInTimelockExecution(address target, bytes memory cd) internal pure returns (bytes memory) {
        return abi.encodeCall(TimelockController.execute, (target, 0, cd, bytes32(0), bytes32(0)));
    }
}
