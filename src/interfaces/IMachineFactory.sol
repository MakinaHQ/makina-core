// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {IMachine} from "./IMachine.sol";
import {IPreDepositVault} from "./IPreDepositVault.sol";
import {IBridgeAdapterFactory} from "./IBridgeAdapterFactory.sol";

interface IMachineFactory is IBridgeAdapterFactory {
    error NotMachine();
    error NotPreDepositVault();

    event HubCaliberDeployed(address indexed caliber);
    event PreDepositVaultDeployed(address indexed preDepositVault, address indexed shareToken);
    event MachineDeployed(address indexed machine, address indexed shareToken, address indexed machineOwner);
    event ShareTokenDeployed(address indexed shareToken);

    /// @notice PreDepositVault => whether the contract was deployed by this factory
    function isPreDepositVault(address preDepositVault) external view returns (bool);

    /// @notice Machine => whether the contract was deployed by this factory
    function isMachine(address machine) external view returns (bool);

    /// @notice Caliber => whether the contract was deployed by this factory
    function isCaliber(address caliber) external view returns (bool);

    /// @notice Deploys a new PreDepositVault instance.
    /// @param params The initialization parameters.
    /// @param tokenName The name of the share token.
    /// @param tokenSymbol The symbol of the share token.
    /// @return preDepositVault The address of the deployed PreDepositVault instance.
    function createPreDepositVault(
        IPreDepositVault.PreDepositVaultInitParams calldata params,
        string memory tokenName,
        string memory tokenSymbol
    ) external returns (address);

    /// @notice Deploys a new Machine instance.
    /// @param params The initialization parameters.
    /// @param token The address of the share token.
    /// @return machine The address of the deployed Machine instance.
    function createMachineFromPreDeposit(IMachine.MachineInitParams calldata params, address token)
        external
        returns (address machine);

    /// @notice Deploys a new Machine instance.
    /// @param params The initialization parameters.
    /// @param tokenName The name of the share token.
    /// @param tokenSymbol The symbol of the share token.
    /// @return machine The address of the deployed Machine instance.
    function createMachine(
        IMachine.MachineInitParams calldata params,
        string memory tokenName,
        string memory tokenSymbol
    ) external returns (address machine);
}
