// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {OFTAdapterMock} from "@layerzerolabs/oft-evm/test/mocks/OFTAdapterMock.sol";

import {ILayerZeroV2BridgeConfig} from "src/interfaces/ILayerZeroV2BridgeConfig.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract SetOft_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2BridgeConfig.setOft(address(0));
    }

    function test_RevertWhen_ZeroTokenAddress() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroOftAddress.selector));
        layerZeroV2BridgeConfig.setOft(address(0));
    }

    function test_SetOft_OFTAdapter() public {
        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.OftRegistered(address(mockOftAdapter), address(baseToken));
        vm.prank(dao);
        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter));

        assertEq(layerZeroV2BridgeConfig.tokenToOft(address(baseToken)), address(mockOftAdapter));
    }

    function test_SetOft_NativeOFT() public {
        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.OftRegistered(address(mockOft), address(mockOft));
        vm.prank(dao);
        layerZeroV2BridgeConfig.setOft(address(mockOft));

        assertEq(layerZeroV2BridgeConfig.tokenToOft(address(mockOft)), address(mockOft));
    }

    function test_SetOft_ReassignOft() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter));

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.OftRegistered(address(mockOftAdapter), address(baseToken));
        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter));

        assertEq(layerZeroV2BridgeConfig.tokenToOft(address(baseToken)), address(mockOftAdapter));
    }

    function test_SetOft_ReassignToken() public {
        vm.startPrank(dao);

        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter));

        OFTAdapterMock mockOftAdapter2 =
            new OFTAdapterMock(address(baseToken), address(mockLzEndpointV2), address(this));

        vm.expectEmit(true, true, false, false, address(layerZeroV2BridgeConfig));
        emit ILayerZeroV2BridgeConfig.OftRegistered(address(mockOftAdapter2), address(baseToken));
        layerZeroV2BridgeConfig.setOft(address(mockOftAdapter2));

        assertEq(layerZeroV2BridgeConfig.tokenToOft(address(baseToken)), address(mockOftAdapter2));
    }
}
