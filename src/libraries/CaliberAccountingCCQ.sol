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
import {Errors} from "src/libraries/Errors.sol";

library CaliberAccountingCCQ {
    function parseAndVerifyQueryResponse(
        address wormhole,
        bytes memory response,
        IWormhole.Signature[] memory signatures
    ) external view returns (QueryResponse memory ret) {
        return QueryResponseLib.parseAndVerifyQueryResponse(wormhole, response, signatures);
    }

    /// @dev Parses the PerChainQueryResponse and retrieves the accounting data for the given caliber mailbox.
    /// @param pcr The PerChainQueryResponse containing the query results.
    /// @param caliberMailbox The address of the queried caliber mailbox.
    /// @return data The accounting data for the given caliber mailbox
    /// @return responseTimestamp The timestamp of the response.
    function getAccountingData(PerChainQueryResponse memory pcr, address caliberMailbox)
        external
        pure
        returns (ICaliberMailbox.SpokeCaliberAccountingData memory, uint256)
    {
        EthCallQueryResponse memory eqr = QueryResponseLib.parseEthCallQueryResponse(pcr);

        // Validate that only one result is returned.
        if (eqr.results.length != 1) {
            revert Errors.UnexpectedResultLength();
        }

        // Validate addresses and function signatures.
        address[] memory validAddresses = new address[](1);
        bytes4[] memory validFunctionSignatures = new bytes4[](1);
        validAddresses[0] = caliberMailbox;
        validFunctionSignatures[0] = ICaliberMailbox.getSpokeCaliberAccountingData.selector;
        QueryResponseLib.validateEthCallRecord(eqr.results[0], validAddresses, validFunctionSignatures);

        return (
            abi.decode(eqr.results[0].result, (ICaliberMailbox.SpokeCaliberAccountingData)),
            eqr.blockTime / QueryResponseLib.MICROSECONDS_PER_SECOND
        );
    }
}
