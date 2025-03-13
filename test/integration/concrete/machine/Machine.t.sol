// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ISpokeCaliberMailbox} from "src/interfaces/ISpokeCaliberMailbox.sol";

import {Integration_Concrete_Hub_Test} from "../IntegrationConcrete.t.sol";

contract Machine_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    uint256 public constant SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_SIZE = 3e18;
    uint256 public constant SPOKE_CALIBER_BASE_TOKEN_POS_SIZE = 4e18;
    uint256 public constant SPOKE_CALIBER_VAULT_POS_SIZE = 5e18;
    uint256 public constant SPOKE_CALIBER_BORROW_POS_SIZE = 20e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_RECEIVED_FROM_HUB = 30e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_BASE_TOKEN_RECEIVED_FROM_HUB = 20e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_SENT_TO_HUB = 10e18;
    uint256 public constant SPOKE_CALIBER_TOTAL_BASE_TOKEN_SENT_TO_HUB = 5e18;

    address public spokeCaliberMailboxAddr;
    address public spokeMachineMailboxAddr;

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();
        _setUpCaliberMerkleRoot(caliber);
        vm.prank(dao);
        chainRegistry.setChainIds(SPOKE_CHAIN_ID, WORMHOLE_SPOKE_CHAIN_ID);
    }

    ///
    /// Helper functions
    ///

    function _buildSpokeCaliberAccountingData_Null()
        internal
        pure
        returns (ISpokeCaliberMailbox.SpokeCaliberAccountingData memory)
    {
        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory data;

        return data;
    }

    function _buildSpokeCaliberAccountingData(bool negativeValue, bool withTransfers)
        internal
        view
        returns (ISpokeCaliberMailbox.SpokeCaliberAccountingData memory)
    {
        ISpokeCaliberMailbox.SpokeCaliberAccountingData memory data;

        data.netAum = negativeValue
            ? 0
            : SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_SIZE + SPOKE_CALIBER_BASE_TOKEN_POS_SIZE + SPOKE_CALIBER_VAULT_POS_SIZE;

        data.positions = new bytes[](negativeValue ? 4 : 3);
        data.positions[0] = abi.encode(SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_ID, SPOKE_CALIBER_ACCOUNTING_TOKEN_POS_SIZE);
        data.positions[1] = abi.encode(SPOKE_CALIBER_BASE_TOKEN_1_POS_ID, SPOKE_CALIBER_BASE_TOKEN_POS_SIZE);
        data.positions[2] = abi.encode(VAULT_POS_ID, SPOKE_CALIBER_VAULT_POS_SIZE);

        if (negativeValue) {
            data.positions[3] = abi.encode(BORROW_POS_ID, SPOKE_CALIBER_BORROW_POS_SIZE);
        }

        if (withTransfers) {
            data.totalReceivedFromHM = new bytes[](2);
            data.totalReceivedFromHM[0] =
                abi.encode(address(accountingToken), SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_RECEIVED_FROM_HUB);
            data.totalReceivedFromHM[1] =
                abi.encode(address(baseToken), SPOKE_CALIBER_TOTAL_BASE_TOKEN_RECEIVED_FROM_HUB);

            data.totalSentToHM = new bytes[](2);
            data.totalSentToHM[0] =
                abi.encode(address(accountingToken), SPOKE_CALIBER_TOTAL_ACCOUNTING_TOKEN_SENT_TO_HUB);
            data.totalSentToHM[1] = abi.encode(address(baseToken), SPOKE_CALIBER_TOTAL_BASE_TOKEN_SENT_TO_HUB);
        }

        return data;
    }
}
