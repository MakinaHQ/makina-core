// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Integration_Concrete_Spoke_Test} from "../IntegrationConcrete.t.sol";

abstract contract SpokeCoreFactory_Integration_Concrete_Test is Integration_Concrete_Spoke_Test {
    address internal accountingAgent;

    function setUp() public virtual override {
        Integration_Concrete_Spoke_Test.setUp();

        accountingAgent = makeAddr("accountingAgent");

        vm.startPrank(dao);
        spokeCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID,
            address(
                _deployAcrossV3BridgeAdapterBeacon(
                    address(accessManager), address(spokeCoreRegistry), address(acrossV3SpokePool)
                )
            )
        );
        vm.stopPrank();
    }
}
