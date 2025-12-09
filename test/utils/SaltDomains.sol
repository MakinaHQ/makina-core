// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

abstract contract SaltDomains {
    bytes32 internal constant ACCESS_MANAGER_SALT_DOMAIN = keccak256("makina.salt.AccessManager");

    bytes32 internal constant CORE_REGISTRY_SALT_DOMAIN = keccak256("makina.salt.CoreRegistry");

    bytes32 internal constant CORE_FACTORY_SALT_DOMAIN = keccak256("makina.salt.CoreFactory");

    bytes32 internal constant ORACLE_REGISTRY_SALT_DOMAIN = keccak256("makina.salt.OracleRegistry");

    bytes32 internal constant CHAIN_REGISTRY_SALT_DOMAIN = keccak256("makina.salt.ChainRegistry");

    bytes32 internal constant TOKEN_REGISTRY_SALT_DOMAIN = keccak256("makina.salt.TokenRegistry");

    bytes32 internal constant SWAP_MODULE_SALT_DOMAIN = keccak256("makina.salt.SwapModule");

    bytes32 internal constant WEIROLL_VM_SALT_DOMAIN = keccak256("makina.salt.WeirollVM");

    bytes32 internal constant MACHINE_BEACON_SALT_DOMAIN = keccak256("makina.salt.MachineBeacon");

    bytes32 internal constant PRE_DEPOSIT_VAULT_SALT_DOMAIN = keccak256("makina.salt.PreDepositVault");

    bytes32 internal constant CALIBER_BEACON_SALT_DOMAIN = keccak256("makina.salt.CaliberBeacon");

    bytes32 internal constant CALIBER_MAILBOX_BEACON_SALT_DOMAIN = keccak256("makina.salt.CaliberMailboxBeacon");

    bytes32 internal constant ACROSS_V3_BRIDGE_ADAPTER_SALT_DOMAIN = keccak256("makina.salt.AcrossV3BridgeAdapter");

    bytes32 internal constant ACROSS_V3_BRIDGE_CONFIG_SALT_DOMAIN = keccak256("makina.salt.AcrossV3BridgeConfig");

    bytes32 internal constant LAYER_ZERO_V2_BRIDGE_ADAPTER_SALT_DOMAIN =
        keccak256("makina.salt.LayerZeroV2BridgeAdapter");

    bytes32 internal constant LAYER_ZERO_V2_CONFIG_SALT_DOMAIN = keccak256("makina.salt.LayerZeroV2Config");
}
