// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ICaliber} from "./ICaliber.sol";
import {IMachine} from "./IMachine.sol";
import {IPreDepositVault} from "./IPreDepositVault.sol";
import {IMakinaGovernable} from "./IMakinaGovernable.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface IHubCoreFactory is IBridgeAdapterFactory {
    event MachineCreated(address indexed machine, address indexed shareToken);
    event PreDepositVaultCreated(address indexed preDepositVault, address indexed shareToken);
    event ShareTokenCreated(address indexed shareToken);

    /// @notice Address => Whether this is a PreDepositVault instance deployed by this factory.
    function isPreDepositVault(address preDepositVault) external view returns (bool);

    /// @notice Address => Whether this is a Machine instance deployed by this factory.
    function isMachine(address machine) external view returns (bool);

    /// @notice Deploys a new PreDepositVault instance.
    /// @param params The initialization parameters.
    /// @param depositToken The address of the deposit token.
    /// @param accountingToken The address of the accounting token.
    /// @param tokenName The name of the share token.
    /// @param tokenSymbol The symbol of the share token.
    /// @return preDepositVault The address of the deployed PreDepositVault instance.
    function createPreDepositVault(
        IPreDepositVault.PreDepositVaultInitParams calldata params,
        address depositToken,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol
    ) external returns (address preDepositVault);

    /// @notice Deploys a new Machine instance and migrates an existing PreDepositVault instance to it.
    /// @param mParams The machine initialization parameters.
    /// @param cParams The caliber initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param preDepositVault The address of the PreDepositVault instance to migrate.
    /// @param salt The salt used to deploy the Hub Caliber deterministically.
    /// @return machine The address of the deployed Machine instance.
    function createMachineFromPreDeposit(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address preDepositVault,
        bytes32 salt
    ) external returns (address machine);

    /// @notice Deploys a new Machine instance.
    /// @param mParams The machine initialization parameters.
    /// @param cParams The caliber initialization parameters.
    /// @param mgParams The makina governable initialization parameters.
    /// @param accountingToken The address of the accounting token.
    /// @param tokenName The name of the share token.
    /// @param tokenSymbol The symbol of the share token.
    /// @param salt The salt used to deploy the Hub Caliber deterministically.
    /// @return machine The address of the deployed Machine instance.
    function createMachine(
        IMachine.MachineInitParams calldata mParams,
        ICaliber.CaliberInitParams calldata cParams,
        IMakinaGovernable.MakinaGovernableInitParams calldata mgParams,
        address accountingToken,
        string memory tokenName,
        string memory tokenSymbol,
        bytes32 salt
    ) external returns (address machine);
}
