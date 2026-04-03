// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICctpV2TokenMessenger {
    function localMinter() external view returns (address);

    function getMinFeeAmount(uint256 amount) external view returns (uint256);

    function depositForBurnWithHook(
        uint256 amount,
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256 maxFee,
        uint32 minFinalityThreshold,
        bytes calldata hookData
    ) external;
}
