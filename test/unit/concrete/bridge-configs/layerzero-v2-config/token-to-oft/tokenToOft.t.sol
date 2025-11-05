// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract tokenToOft_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_RevertWhen_OftNotRegistered() public {
        vm.expectRevert(abi.encodeWithSelector(Errors.OftNotRegistered.selector, address(baseToken)));
        layerZeroV2Config.tokenToOft(address(baseToken));

        vm.prank(dao);
        layerZeroV2Config.setOft(address(mockOftAdapter));

        vm.expectRevert(abi.encodeWithSelector(Errors.OftNotRegistered.selector, address(mockOftAdapter)));
        layerZeroV2Config.tokenToOft(address(mockOftAdapter));
    }
}
