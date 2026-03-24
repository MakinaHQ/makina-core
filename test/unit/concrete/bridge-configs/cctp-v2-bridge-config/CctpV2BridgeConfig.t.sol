// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {CctpV2BridgeConfig} from "src/bridge/configs/CctpV2BridgeConfig.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract CctpV2BridgeConfig_Unit_Concrete_Test is Base_Test {
    MockERC20 internal baseToken;

    CctpV2BridgeConfig internal cctpV2BridgeConfig;

    function setUp() public virtual override {
        Base_Test.setUp();

        baseToken = new MockERC20("Base Token", "BT", 18);

        accessManager = _deployAccessManager(deployer, deployer);
        cctpV2BridgeConfig = _deployCctpV2BridgeConfig(address(accessManager), address(accessManager));

        _setupCctpV2BridgeConfigAMFunctionRoles(address(accessManager), address(cctpV2BridgeConfig));
        setupAccessManagerRolesAndOwnership();
    }
}
