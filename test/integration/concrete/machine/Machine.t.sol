// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {AcrossV3BridgeConfig} from "src/bridge/configs/AcrossV3BridgeConfig.sol";
import {ICoreRegistry} from "src/interfaces/ICoreRegistry.sol";
import {IBridgeAdapterFactory} from "src/interfaces/IBridgeAdapterFactory.sol";
import {IBridgeController} from "src/interfaces/IBridgeController.sol";
import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

import {BridgeController_Integration_Concrete_Test} from "../bridge-controller/BridgeController.t.sol";
import {
    SetBridgeAdapter_Integration_Concrete_Test
} from "../bridge-controller/set-bridge-adapter/setBridgeAdapter.t.sol";
import {
    GetBridgeAdapter_Integration_Concrete_Test
} from "../bridge-controller/get-bridge-adapter/getBridgeAdapter.t.sol";
import {
    GetMaxBridgeLossBps_Integration_Concrete_Test
} from "../bridge-controller/get-max-bridge-loss-bps/getMaxBridgeLossBps.t.sol";
import {
    IsBridgeSupported_Integration_Concrete_Test
} from "../bridge-controller/is-bridge-supported/isBridgeSupported.t.sol";
import {
    IsOutTransferEnabled_Integration_Concrete_Test
} from "../bridge-controller/is-out-transfer-enabled/isOutTransferEnabled.t.sol";
import {
    SetMaxBridgeLossBps_Integration_Concrete_Test
} from "../bridge-controller/set-max-bridge-loss-bps/setMaxBridgeLossBps.t.sol";
import {
    EnableOutTransfer_Integration_Concrete_Test
} from "../bridge-controller/enable-out-transfer/enableOutTransfer.t.sol";
import {
    DisableOutTransfer_Integration_Concrete_Test
} from "../bridge-controller/disable-out-transfer/disableOutTransfer.t.sol";
import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

abstract contract Machine_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    uint256 internal constant SPOKE_CALIBER_NET_AUM = 15e18;

    address internal spokeAccountingTokenAddr;
    address internal spokeBaseTokenAddr;
    address internal spokeCaliberMailboxAddr;
    address internal spokeBridgeAdapterAddr;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);

        spokeCaliberMailboxAddr = makeAddr("spokeCaliberMailbox");
        spokeAccountingTokenAddr = makeAddr("spokeAccountingToken");
        spokeBaseTokenAddr = makeAddr("spokeBaseToken");
        spokeBridgeAdapterAddr = makeAddr("spokeBridgeAdapter");

        vm.startPrank(address(dao));

        machine.addCreWorkflowId(DEFAULT_CRE_WORKFLOW_ID);

        hubCoreRegistry.setBridgeAdapterBeacon(
            ACROSS_V3_BRIDGE_ID,
            address(
                _deployAcrossV3BridgeAdapterBeacon(
                    address(accessManager), address(hubCoreRegistry), address(acrossV3SpokePool)
                )
            )
        );
        AcrossV3BridgeConfig config = _deployAcrossV3BridgeConfig(address(accessManager), address(accessManager));
        hubCoreRegistry.setBridgeConfig(ACROSS_V3_BRIDGE_ID, address(config));
        config.setForeignChainSupported(SPOKE_CHAIN_ID, true);

        vm.stopPrank();
    }

    ///
    /// Helper functions
    ///

    function _buildSpokeCaliberAccountingReport_Empty() internal pure returns (bytes memory) {
        ICaliberMailbox.SpokeCaliberAccountingData[] memory snapshots =
            new ICaliberMailbox.SpokeCaliberAccountingData[](1);

        return abi.encode(snapshots);
    }

    function _buildSpokeCaliberAccountingReport(uint256 chainId, uint256 blockNum, uint256 blockTime, bool nullValue)
        internal
        view
        returns (bytes memory)
    {
        return _buildSpokeCaliberAccountingReportWithTransfers(
            chainId, blockNum, blockTime, nullValue, 0, new bytes[](0), new bytes[](0)
        );
    }

    function _buildSpokeCaliberAccountingReportWithTransfers(
        uint256 chainId,
        uint256 blockNum,
        uint256 blockTime,
        bool nullValue,
        uint256 aumOffsetTransfers,
        bytes[] memory bridgesIn,
        bytes[] memory bridgesOut
    ) internal view returns (bytes memory) {
        ICaliberMailbox.SpokeCaliberAccountingData memory snapshot;

        snapshot.netAum = nullValue ? 0 : SPOKE_CALIBER_NET_AUM;
        snapshot.netAum += aumOffsetTransfers;

        snapshot.context = ICaliberMailbox.SpokeSnapshotContext({
            chainId: chainId, mailbox: spokeCaliberMailboxAddr, blockNum: blockNum, blockTime: blockTime
        });

        snapshot.bridgesIn = bridgesIn;
        snapshot.bridgesOut = bridgesOut;

        ICaliberMailbox.SpokeCaliberAccountingData[] memory snapshots =
            new ICaliberMailbox.SpokeCaliberAccountingData[](1);
        snapshots[0] = snapshot;

        return abi.encode(snapshots);
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
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
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
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
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
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
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
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract SetBridgeAdapter_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    SetBridgeAdapter_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
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
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract EnableOutTransfer_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    EnableOutTransfer_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}

contract DisableOutTransfer_Machine_Integration_Concrete_Test is
    BridgeController_Machine_Integration_Concrete_Test,
    DisableOutTransfer_Integration_Concrete_Test
{
    function setUp()
        public
        virtual
        override(BridgeController_Machine_Integration_Concrete_Test, BridgeController_Integration_Concrete_Test)
    {
        BridgeController_Machine_Integration_Concrete_Test.setUp();
    }
}
