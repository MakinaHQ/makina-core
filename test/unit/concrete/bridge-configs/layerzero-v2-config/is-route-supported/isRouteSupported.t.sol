// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroV2Config_Unit_Concrete_Test} from "../LayerZeroV2Config.t.sol";

contract IsRouteSupported_Unit_Concrete_Test is LayerZeroV2Config_Unit_Concrete_Test {
    function test_IsRouteSupported() public {
        address foreignToken = makeAddr("foreignToken");

        vm.startPrank(address(dao));

        assertFalse(layerZeroV2Config.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2Config.setLzChainId(1, 2);

        assertFalse(layerZeroV2Config.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2Config.setOft(address(mockOft));

        assertFalse(layerZeroV2Config.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2Config.setForeignToken(address(mockOft), 1, foreignToken);

        assertTrue(layerZeroV2Config.isRouteSupported(address(mockOft), 1, foreignToken));
    }
}
