// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

interface ICaliberFactory {
    function caliberBeacon() external view returns (address);

    function isCaliber(address caliber) external view returns (bool);

    function deployCaliber(
        address _hubMachine,
        address _accountingToken,
        uint256 _acountingTokenPosID,
        bytes32 _initialAllowedInstrRoot,
        uint256 _initialTimelockDuration,
        address _initialMechanic,
        address _initialSecurityCouncil
    ) external returns (address);
}
