// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IAccessManaged} from "@openzeppelin/contracts/access/manager/IAccessManaged.sol";

import {OFTAdapterMock} from "@layerzerolabs/oft-evm/test/mocks/OFTAdapterMock.sol";

import {ILayerZeroV2Config} from "src/interfaces/ILayerZeroV2Config.sol";
import {Errors} from "src/libraries/Errors.sol";

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract SetOft_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_RevertWhen_CallerWithoutRole() public {
        vm.expectRevert(abi.encodeWithSelector(IAccessManaged.AccessManagedUnauthorized.selector, address(this)));
        layerZeroV2Config.setOft(address(0));
    }

    function test_RevertWhen_ZeroTokenAddress() public {
        vm.startPrank(dao);

        vm.expectRevert(abi.encodeWithSelector(Errors.ZeroOftAddress.selector));
        layerZeroV2Config.setOft(address(0));
    }

    function test_SetOft_OFTAdapter() public {
        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.OftRegistered(address(mockOftAdapter), address(baseToken));
        vm.prank(dao);
        layerZeroV2Config.setOft(address(mockOftAdapter));

        assertEq(layerZeroV2Config.tokenToOft(address(baseToken)), address(mockOftAdapter));
    }

    function test_SetOft_NativeOFT() public {
        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.OftRegistered(address(mockOft), address(mockOft));
        vm.prank(dao);
        layerZeroV2Config.setOft(address(mockOft));

        assertEq(layerZeroV2Config.tokenToOft(address(mockOft)), address(mockOft));
    }

    function test_SetOft_ReassignOft() public {
        vm.startPrank(dao);

        layerZeroV2Config.setOft(address(mockOftAdapter));

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.OftRegistered(address(mockOftAdapter), address(baseToken));
        layerZeroV2Config.setOft(address(mockOftAdapter));

        assertEq(layerZeroV2Config.tokenToOft(address(baseToken)), address(mockOftAdapter));
    }

    function test_SetOft_ReassignToken() public {
        vm.startPrank(dao);

        layerZeroV2Config.setOft(address(mockOftAdapter));

        OFTAdapterMock mockOftAdapter2 =
            new OFTAdapterMock(address(baseToken), address(mockLzEndpointV2), address(this));

        vm.expectEmit(true, true, false, false, address(layerZeroV2Config));
        emit ILayerZeroV2Config.OftRegistered(address(mockOftAdapter2), address(baseToken));
        layerZeroV2Config.setOft(address(mockOftAdapter2));

        assertEq(layerZeroV2Config.tokenToOft(address(baseToken)), address(mockOftAdapter2));
    }
}
