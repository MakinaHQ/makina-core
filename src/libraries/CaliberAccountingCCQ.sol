// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";
import {
    EthCallQueryResponse,
    PerChainQueryResponse,
    QueryResponse,
    QueryResponseLib
} from "@wormhole/sdk/libraries/QueryResponse.sol";
import {GuardianSignature} from "@wormhole/sdk/libraries/VaaLib.sol";

import {ICaliberMailbox} from "../interfaces/ICaliberMailbox.sol";
import {Errors} from "./Errors.sol";

library CaliberAccountingCCQ {
    function decodeAndVerifyQueryResponse(
        address wormhole,
        bytes calldata response,
        GuardianSignature[] calldata signatures
    ) external view returns (QueryResponse memory ret) {
        return QueryResponseLib.decodeAndVerifyQueryResponseCd(
            wormhole, response, signatures, IWormhole(wormhole).getCurrentGuardianSetIndex()
        );
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
        EthCallQueryResponse memory eqr = QueryResponseLib.decodeEthCallQueryResponse(pcr);

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
