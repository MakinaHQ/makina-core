// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapter} from "src/interfaces/IBridgeAdapter.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {MockERC20} from "test/mocks/MockERC20.sol";
import {MockMachineEndpoint} from "test/mocks/MockMachineEndpoint.sol";

import {Base_Test} from "test/base/Base.t.sol";

abstract contract BridgeAdapter_Integration_Concrete_Test is Base_Test {
    MockMachineEndpoint public bridgeController1;
    MockMachineEndpoint public bridgeController2;

    IBridgeAdapter public bridgeAdapter1;
    IBridgeAdapter public bridgeAdapter2;

    MockERC20 public token1;
    MockERC20 public token2;
    MockERC20 public token3;

    uint256 public chainId1;
    uint256 public chainId2;

    ICoreRegistry public coreRegistry;

    function setUp() public virtual override {
        Base_Test.setUp();

        chainId1 = block.chainid;
        chainId2 = chainId1 + 1;

        bridgeController1 = new MockMachineEndpoint();
        bridgeController2 = new MockMachineEndpoint();

        token1 = new MockERC20("Token1", "T1", 18);
        token2 = new MockERC20("Token2", "T2", 18);
        token3 = new MockERC20("Token3", "T3", 18);

        accessManager = _deployAccessManager(deployer, deployer);
        coreRegistry = ICoreRegistry(
            address(
                _deployHubCoreRegistry(
                    address(accessManager), address(0), address(0), address(0), address(accessManager)
                )
            )
        );
    }

    ///
    /// UTILS
    ///

    /// @dev Sends out scheduled outgoing bridge transfer. To be overridden for each bridge adapter version.
    function _sendOutBridgeTransfer(address, /*bridgeAdapter*/ uint256 /*transferId*/ ) internal virtual {}

    /// @dev Simulates incoming bridge transfer reception. To be overridden for each bridge adapter version.
    function _receiveInBridgeTransfer(
        address, /*bridgeAdapter*/
        bytes memory, /* encodedMessage*/
        address, /*receivedToken*/
        uint256 /*receivedAmount*/
    ) internal virtual {}
}
