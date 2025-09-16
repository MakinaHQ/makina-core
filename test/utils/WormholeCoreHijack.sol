// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.28;

import {Vm} from "forge-std/Vm.sol";

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {WormholeQueryTestHelpers} from "../utils/WormholeQueryTestHelpers.sol";

library WormholeCoreHijack {
    bytes32 private constant GUARDIAN_SETS_SLOT = bytes32(uint256(0x2));
    bytes32 private constant GUARDIAN_SET_INDEX_SLOT = bytes32(uint256(0x3));

    uint32 private constant GUARDIAN_SET_INDEX_DEFAULT = 0;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Hijacks a core wormhole contract by overriding its guardian set with the devnet guardian,
    /// using `vm.store()`. This allows to forge signed VAAs in fork tests.
    function hijackWormholeCore(address wormhole) external {
        uint32 guardianSetExpiry = IWormhole(wormhole).getGuardianSetExpiry();

        // set guardian set index to 0
        vm.store(
            wormhole,
            GUARDIAN_SET_INDEX_SLOT,
            bytes32((uint256(guardianSetExpiry) << 32) | uint256(GUARDIAN_SET_INDEX_DEFAULT))
        );

        bytes32 gsSlot = keccak256(abi.encode(uint256(GUARDIAN_SET_INDEX_DEFAULT), uint256(GUARDIAN_SETS_SLOT)));

        // store the guardian set's keys array length
        vm.store(wormhole, gsSlot, bytes32(uint256(1)));

        // store the guardian set's first key
        bytes32 keysArraySlot = keccak256(abi.encode(gsSlot));
        vm.store(wormhole, keysArraySlot, bytes32(uint256(uint160(WormholeQueryTestHelpers.DEVNET_GUARDIAN_ADDRESS))));
    }
}
