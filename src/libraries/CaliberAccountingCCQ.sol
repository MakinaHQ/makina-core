// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {
    EthCallQueryResponse,
    PerChainQueryResponse,
    QueryResponse,
    QueryResponseLib
} from "@wormhole/sdk/libraries/QueryResponse.sol";

import {ICaliberMailbox} from "src/interfaces/ICaliberMailbox.sol";

library CaliberAccountingCCQ {
    error StaleData();
    error UnexpectedResultLength();

    function parseAndVerifyQueryResponse(
        address wormhole,
        bytes memory response,
        IWormhole.Signature[] memory signatures
    ) external view returns (QueryResponse memory ret) {
        return QueryResponseLib.parseAndVerifyQueryResponse(wormhole, response, signatures);
    }

    /// @dev Parses the PerChainQueryResponse and retrieves the accounting data for the specified caliber mailbox.
    /// @param pcr The PerChainQueryResponse containing the query results.
    /// @param caliberMailbox The address of the caliber mailbox to retrieve data for.
    /// @param lastTimestamp The timestamp of the last accounting data update.
    /// @param staleThreshold The accounting data staleness threshold.
    /// @return data The accounting data for the specified caliber mailbox
    /// @return responseTimestamp The timestamp of the response.
    function getAccountingData(
        PerChainQueryResponse memory pcr,
        address caliberMailbox,
        uint256 lastTimestamp,
        uint256 staleThreshold
    ) external view returns (ICaliberMailbox.SpokeCaliberAccountingData memory, uint256) {
        EthCallQueryResponse memory eqr = QueryResponseLib.parseEthCallQueryResponse(pcr);

        // Validate that update is not older than current chain last update, nor stale.
        uint256 responseTimestamp = eqr.blockTime / QueryResponseLib.MICROSECONDS_PER_SECOND;
        if (
            responseTimestamp < lastTimestamp
                || (block.timestamp > responseTimestamp && block.timestamp - responseTimestamp >= staleThreshold)
        ) {
            revert StaleData();
        }

        // Validate that only one result is returned.
        if (eqr.results.length != 1) {
            revert UnexpectedResultLength();
        }

        // Validate addresses and function signatures.
        address[] memory validAddresses = new address[](1);
        bytes4[] memory validFunctionSignatures = new bytes4[](1);
        validAddresses[0] = caliberMailbox;
        validFunctionSignatures[0] = ICaliberMailbox.getSpokeCaliberAccountingData.selector;
        QueryResponseLib.validateEthCallRecord(eqr.results[0], validAddresses, validFunctionSignatures);

        return (abi.decode(eqr.results[0].result, (ICaliberMailbox.SpokeCaliberAccountingData)), responseTimestamp);
    }
}
