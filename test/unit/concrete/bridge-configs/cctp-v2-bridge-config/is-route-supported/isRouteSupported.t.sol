// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CctpV2BridgeConfig_Unit_Concrete_Test} from "../CctpV2BridgeConfig.t.sol";

contract IsRouteSupported_Unit_Concrete_Test is CctpV2BridgeConfig_Unit_Concrete_Test {
    function test_IsRouteSupported() public {
        address foreignToken = makeAddr("foreignToken");

        vm.startPrank(address(dao));

        assertFalse(cctpV2BridgeConfig.isRouteSupported(address(baseToken), 2, foreignToken));

        cctpV2BridgeConfig.setCctpDomain(2, 3);

        assertFalse(cctpV2BridgeConfig.isRouteSupported(address(baseToken), 2, foreignToken));

        cctpV2BridgeConfig.setForeignToken(address(baseToken), 2, foreignToken);

        assertTrue(cctpV2BridgeConfig.isRouteSupported(address(baseToken), 2, foreignToken));

        assertFalse(cctpV2BridgeConfig.isRouteSupported(address(baseToken), 1, foreignToken));

        cctpV2BridgeConfig.setForeignToken(address(baseToken), 1, foreignToken);

        assertTrue(cctpV2BridgeConfig.isRouteSupported(address(baseToken), 1, foreignToken));
    }
}
