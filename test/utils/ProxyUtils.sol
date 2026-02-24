// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";

abstract contract ProxyUtils {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    // Returns the admin of a transparent proxy by reading the proxy's storage slot directly.
    // The slot is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
    // See OpenZeppelin's ERC1967Utils for reference.
    function getProxyAdmin(address _transparentProxy) internal view returns (address) {
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        return address(uint160(uint256(vm.load(_transparentProxy, ADMIN_SLOT))));
    }
}
