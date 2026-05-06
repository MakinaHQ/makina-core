// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

/// @notice Logs ProxyAdmin addresses for all TransparentUpgradeableProxy contracts.
/// Run with: forge script script/deployments/LogProxyAdmins.s.sol --rpc-url <RPC_URL>
/// Hub-only contracts (ChainRegistry, periphery) require a mainnet RPC.
contract LogProxyAdmins is Script {
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function run() public view {
        console.log("== Core Infrastructure (all chains) ==");
        _logProxyAdmin("AccessManager", 0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F);
        _logProxyAdmin("CoreRegistry", 0x0FAEeCEab0BCb63bE2Fe984Ea8c77778989d53eA);
        _logProxyAdmin("CoreFactory", 0x8d28A69328561eF9F171c58996fEcB9F494e070c);
        _logProxyAdmin("OracleRegistry", 0xC388B72AB90Be82B230D919F9C05c87F9397f485);
        _logProxyAdmin("TokenRegistry", 0xd9310A41d085c0DC1E40F691e8647080862A5fd4);
        _logProxyAdmin("SwapModule", 0x923c98b22F9c367A109E93f7dfBaCa28b20C17C3);
        _logProxyAdmin("AcrossV3BridgeConfig", 0xDdE7FD6f25c9a58c5ec3E278d31e8584f236da86);
        _logProxyAdmin("LayerZeroV2BridgeConfig", 0x1B064336D9C4999C942Ecc36e36d48a411343771);
        _logProxyAdmin("CctpV2BridgeConfig", 0x1be75B412cc8bE1bf64A84D40322dD889cfD6134);

        console.log("");
        console.log("== Hub-only Core (mainnet) ==");
        _logProxyAdmin("ChainRegistry", 0x45681FCf26EF1dCa89ae2B8B97c6447ea68771Df);

        console.log("");
        console.log("== Hub Periphery (mainnet) ==");
        _logProxyAdmin("HubPeripheryRegistry", 0xc0109106a2E119087a5739c9532ec7e1B039EE05);
        _logProxyAdmin("HubPeripheryFactory", 0xd6aeeEBCCC245dAa4146F54B75686C33C96c30dA);
        _logProxyAdmin("MachineShareOracleFactory", 0x58DE6381cBCc919D72e6A2507cAe74925E69Daf5);
        _logProxyAdmin("MetaMorphoOracleFactory", 0xA793e9548337654237BFa49fFD2188236d02e6A7);
    }

    function _logProxyAdmin(string memory name, address proxy) internal view {
        address admin = address(uint160(uint256(vm.load(proxy, ADMIN_SLOT))));
        console.log(name, "ProxyAdmin:", admin);
    }
}
