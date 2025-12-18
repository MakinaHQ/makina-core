// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {LayerZeroV2BridgeConfig_Unit_Concrete_Test} from "../LayerZeroV2BridgeConfig.t.sol";

contract IsRouteSupported_Unit_Concrete_Test is LayerZeroV2BridgeConfig_Unit_Concrete_Test {
    function test_IsRouteSupported() public {
        address foreignToken = makeAddr("foreignToken");

        vm.startPrank(address(dao));

        assertFalse(layerZeroV2BridgeConfig.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2BridgeConfig.setLzChainId(1, 2);

        assertFalse(layerZeroV2BridgeConfig.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2BridgeConfig.setOft(address(mockOft));

        assertFalse(layerZeroV2BridgeConfig.isRouteSupported(address(mockOft), 1, foreignToken));

        layerZeroV2BridgeConfig.setForeignToken(address(mockOft), 1, foreignToken);

        assertTrue(layerZeroV2BridgeConfig.isRouteSupported(address(mockOft), 1, foreignToken));
    }
}
