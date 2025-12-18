// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract tokenToOft_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_OftNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.OftNotRegistered.selector, address(baseToken)));
        layerZeroV2BridgeConfig.tokenToOft(address(baseToken));

        vm.prank(dao);
        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter));

        vm.expectRevert(abi.encodeWithSelector(Errors.OftNotRegistered.selector, address(mockOftAdapter)));
        layerZeroV2BridgeConfig.tokenToOft(address(mockOftAdapter));
    }
}
