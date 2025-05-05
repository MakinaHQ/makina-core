// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {BridgeController_Integration_Concrete_Test} from "../bridge-controller/BridgeController.t.sol";
import {CreateBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/create-bridge-adapter/createBridgeAdapter.t.sol";
import {GetBridgeAdapter_Integration_Concrete_Test} from
    "../bridge-controller/get-bridge-adapter/getBridgeAdapter.t.sol";
import {GetMaxBridgeLossBps_Integration_Concrete_Test} from
    "../bridge-controller/get-max-bridge-loss-bps/getMaxBridgeLossBps.t.sol";
import {IsBridgeSupported_Integration_Concrete_Test} from
    "../bridge-controller/is-bridge-supported/isBridgeSupported.t.sol";
import {IsOutTransferEnabled_Integration_Concrete_Test} from
    "../bridge-controller/is-out-transfer-enabled/isOutTransferEnabled.t.sol";
import {SetMaxBridgeLossBps_Integration_Concrete_Test} from
    "../bridge-controller/set-max-bridge-loss-bps/setMaxBridgeLossBps.t.sol";
import {SetOutTransferEnabled_Integration_Concrete_Test} from
    "../bridge-controller/set-out-transfer-enabled/setOutTransferEnabled.t.sol";
import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

abstract contract Machine_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    uint256 public constant SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE = 3e18;
    uint256 public constant SPOKE_CALIBER_BASE_TOKEN_VALUE = 4e18;
    uint256 public constant SPOKE_CALIBER_VAULT_VALUE = 5e18;
    uint256 public constant SPOKE_CALIBER_BORROW_VALUE = 20e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_RECEIVED_FROM_HUB = 30e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_BASE_TOKEN_RECEIVED_FROM_HUB = 20e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_SENT_TO_HUB = 10e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_BASE_TOKEN_SENT_TO_HUB = 5e18;

    uint256 public constant TOTAL_SPOKE_CALIBER_POSITIVE_POSITIONS_VALUE =
        SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE + SPOKE_CALIBER_BASE_TOKEN_VALUE + SPOKE_CALIBER_VAULT_VALUE;
    uint256 public constant TOTAL_SPOKE_CALIBER_NEGATIVE_POSITIONS_VALUE = SPOKE_CALIBER_BORROW_VALUE;

    address public spokeAccountingTokenAddr;
    address public spokeBaseTokenAddr;
    address public spokeCaliberMailboxAddr;
    address public spokeBridgeAdapterAddr;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
        vm.prank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID, WORMHOLE_SPOKE_CHAIN_ID);

        spokeCaliberMailboxAddr = makeAddr("spokeCaliberMailbox");
        spokeAccountingTokenAddr = makeAddr("spokeAccountingToken");
        spokeBaseTokenAddr = makeAddr("spokeBaseToken");
        spokeBridgeAdapterAddr = makeAddr("spokeBridgeAdapter");

        vm.startPrank(address(dao));
        hubCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID, address(_deployAcrossV3BridgeAdapterBeacon(dao, address(acrossV3SpokePool)))
        );
        vm.stopPrank();
    }

    ///
    /// Helper functions
    ///

    function _buildSpokeCaliberAccountingData_Null()
        internal
        pure
        returns (ICaliberMailbox.SpokeCaliberAccountingData memory)
    {
        ICaliberMailbox.SpokeCaliberAccountingData memory data;

        return data;
    }

    function _buildSpokeCaliberAccountingData(bool negativeValue)
        internal
        view
        returns (ICaliberMailbox.SpokeCaliberAccountingData memory)
    {
        ICaliberMailbox.SpokeCaliberAccountingData memory data;

        data.netAum = negativeValue
            ? 0
            : SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE + SPOKE_CALIBER_BASE_TOKEN_VALUE + SPOKE_CALIBER_VAULT_VALUE;

        data.positions = new bytes[](negativeValue ? 2 : 1);
        data.positions[0] = abi.encode(VAULT_POS_ID, SPOKE_CALIBER_VAULT_VALUE, false);

        if (negativeValue) {
            data.positions[1] = abi.encode(BORROW_POS_ID, SPOKE_CALIBER_BORROW_VALUE, true);
        }

        data.baseTokens = new bytes[](2);
        data.baseTokens[0] = abi.encode(spokeAccountingTokenAddr, SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE);
        data.baseTokens[1] = abi.encode(spokeBaseTokenAddr, SPOKE_CALIBER_BASE_TOKEN_VALUE);

        return data;
    }

    function _buildSpokeCaliberAccountingDataWithTransfers(
        bool negativeValue,
        uint256 aumOffsetTransfers,
        bytes[] memory bridgesIn,
        bytes[] memory bridgesOut
    ) internal view returns (ICaliberMailbox.SpokeCaliberAccountingData memory) {
        ICaliberMailbox.SpokeCaliberAccountingData memory data;

        data.netAum = negativeValue
            ? 0
            : SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE + SPOKE_CALIBER_BASE_TOKEN_VALUE + SPOKE_CALIBER_VAULT_VALUE;

        data.netAum += aumOffsetTransfers;

        data.positions = new bytes[](negativeValue ? 2 : 1);
        data.positions[0] = abi.encode(VAULT_POS_ID, SPOKE_CALIBER_VAULT_VALUE, false);

        if (negativeValue) {
            data.positions[1] = abi.encode(BORROW_POS_ID, SPOKE_CALIBER_BORROW_VALUE, true);
        }

        data.baseTokens = new bytes[](2);
        data.baseTokens[0] = abi.encode(spokeAccountingTokenAddr, SPOKE_CALIBER_ACCOUNTING_TOKEN_VALUE);
        data.baseTokens[1] = abi.encode(spokeBaseTokenAddr, SPOKE_CALIBER_BASE_TOKEN_VALUE);

        data.bridgesIn = bridgesIn;
        data.bridgesOut = bridgesOut;

        return data;
    }
}

abstract contract BridgeController_Machine_Integration_Concrete_Test is
    Machine_Integration_Concrete_Test,
    BridgeController_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        Machine_Integration_Concrete_Test.setUp();

        registry = ICoreRegistry(address(hubCoreRegistry));
        bridgeController = IBridgeController(address(machine));
        bridgeAdapterFactory = IBridgeAdapterFactory(address(hubCoreFactory));
    }
}

contract IsBridgeSupported_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    IsBridgeSupported_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, IsBridgeSupported_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract IsOutTransferEnabled_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    IsOutTransferEnabled_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, IsOutTransferEnabled_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract GetBridgeAdapter_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    GetBridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, GetBridgeAdapter_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract GetMaxBridgeLossBps_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    GetMaxBridgeLossBps_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, GetMaxBridgeLossBps_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract CreateBridgeAdapter_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    CreateBridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, CreateBridgeAdapter_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract SetMaxBridgeLossBps_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    SetMaxBridgeLossBps_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, SetMaxBridgeLossBps_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract SetOutTransferEnabled_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    SetOutTransferEnabled_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, SetOutTransferEnabled_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}
