// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {ProxyAdmin} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {ITransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {AccessManagerUpgradeable} from
    "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

/// @dev Temporary implementation that re-grants ADMIN_ROLE via reinitializer(2).
contract AccessManagerFixer is AccessManagerUpgradeable {
    function grantAdmin(address admin) external reinitializer(2) {
        _grantRole(ADMIN_ROLE, admin, 0, 0);
    }
}

contract FixAccessManager is Script {
    function run() public {
        address proxyAdmin = 0x295e6E1BbCd33A13a8b125B5a32AbFD1c61a6A7F;
        address accessManagerProxy = 0x94EDcE340D49ce11Aef1620B63c095e121893bAF;
        address originalImpl = 0xEeE36613e4F57Efcb9D83003E5350a7A4b5698C6;
        address superAdmin = 0xb7444CCf1236b5df1B7820a551268E9ee420cEf4;

        vm.startBroadcast();

        // 1. Deploy the fixer implementation
        AccessManagerFixer fixer = new AccessManagerFixer();

        // 2. Upgrade to fixer and call grantAdmin to restore ADMIN_ROLE
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(accessManagerProxy),
            address(fixer),
            abi.encodeCall(AccessManagerFixer.grantAdmin, (superAdmin))
        );

        // 3. Upgrade back to original implementation
        ProxyAdmin(proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(accessManagerProxy), originalImpl, ""
        );

        vm.stopBroadcast();
    }
}
