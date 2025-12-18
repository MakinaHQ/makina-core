// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {ILayerZeroEndpointV2} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";
import {OFTAdapterMock} from "@layerzerolabs/oft-evm/test/mocks/OFTAdapterMock.sol";
import {OFTMock} from "@layerzerolabs/oft-evm/test/mocks/OFTMock.sol";

import {LayerZeroV2BridgeConfig} from "src/bridge/configs/LayerZeroV2BridgeConfig.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract LayerZeroV2BridgeConfig_Unit_Concrete_Test is Base_Test {
    MockERC20 internal baseToken;
    ILayerZeroEndpointV2 internal mockLzEndpointV2;
    OFTAdapterMock internal mockOftAdapter;
    OFTMock internal mockOft;

    LayerZeroV2BridgeConfig public layerZeroV2BridgeConfig;

    function setUp() public virtual override {
        Base_Test.setUp();

        baseToken = new MockERC20("Base Token", "BT", 18);
        mockLzEndpointV2 = ILayerZeroEndpointV2(
            _deployCode(abi.encodePacked(getMockLayerZeroEndpointV2Code(), abi.encode(0, address(this))), 0)
        );
        mockOftAdapter = new OFTAdapterMock(address(baseToken), address(mockLzEndpointV2), address(this));
        mockOft = new OFTMock("Mock OFT", "MOFT", address(mockLzEndpointV2), address(this));

        accessManager = _deployAccessManager(deployer, dao);
        layerZeroV2BridgeConfig = _deployLayerZeroV2BridgeConfig(dao, address(accessManager));

        _setupLayerZeroV2BridgeConfigAMFunctionRoles(address(accessManager), address(layerZeroV2BridgeConfig));
        setupAccessManagerRoles(accessManager, address(0), dao, address(0), address(0), address(0), deployer);
    }
}
