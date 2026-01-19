// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import "@wormhole/sdk/constants/Chains.sol" as WormholeChains;

library ChainsInfo {
    error InvalidChainId();

    struct ChainInfo {
        uint256 evmChainId;
        uint16 wormholeChainId;
        string name;
        string foundryAlias;
        string constantsFilename;
    }

    uint256 public constant CHAIN_ID_ETHEREUM = 1;
    uint256 public constant CHAIN_ID_BASE = 8453;
    uint256 public constant CHAIN_ID_ABITRUM = 42161;
    uint256 public constant CHAIN_ID_OPTIMISM = 10;
    uint256 public constant CHAIN_ID_INK = 57073;
    uint256 public constant CHAIN_ID_AVALANCHE = 43114;
    uint256 public constant CHAIN_ID_UNICHAIN = 130;
    uint256 public constant CHAIN_ID_WORLDCHAIN = 480;
    uint256 public constant CHAIN_ID_MONAD = 143;
    uint256 public constant CHAIN_ID_PLASMA = 9745;
    uint256 public constant CHAIN_ID_HYPER_EVM = 999;

    function getChainInfo(uint256 chainId) internal pure returns (ChainInfo memory) {
        if (chainId == CHAIN_ID_ETHEREUM) {
            return ChainInfo({
                evmChainId: CHAIN_ID_ETHEREUM,
                wormholeChainId: WormholeChains.CHAIN_ID_ETHEREUM,
                name: "Ethereum",
                foundryAlias: "mainnet",
                constantsFilename: "Mainnet-Test.json"
            });
        } else if (chainId == CHAIN_ID_BASE) {
            return ChainInfo({
                evmChainId: CHAIN_ID_BASE,
                wormholeChainId: WormholeChains.CHAIN_ID_BASE,
                name: "Base",
                foundryAlias: "base",
                constantsFilename: "Base-Test.json"
            });
        } else if (chainId == CHAIN_ID_ABITRUM) {
            return ChainInfo({
                evmChainId: CHAIN_ID_ABITRUM,
                wormholeChainId: WormholeChains.CHAIN_ID_ARBITRUM,
                name: "Arbitrum",
                foundryAlias: "arbitrum_one",
                constantsFilename: "Arbitrum-Test.json"
            });
        } else if (chainId == CHAIN_ID_OPTIMISM) {
            return ChainInfo({
                evmChainId: CHAIN_ID_OPTIMISM,
                wormholeChainId: WormholeChains.CHAIN_ID_OPTIMISM,
                name: "Optimism",
                foundryAlias: "optimism",
                constantsFilename: "OP-Test.json"
            });
        } else if (chainId == CHAIN_ID_INK) {
            return ChainInfo({
                evmChainId: CHAIN_ID_INK,
                wormholeChainId: WormholeChains.CHAIN_ID_INK,
                name: "Ink",
                foundryAlias: "ink",
                constantsFilename: "Ink-Test.json"
            });
        } else if (chainId == CHAIN_ID_AVALANCHE) {
            return ChainInfo({
                evmChainId: CHAIN_ID_AVALANCHE,
                wormholeChainId: WormholeChains.CHAIN_ID_AVALANCHE,
                name: "Avalanche",
                foundryAlias: "avalanche",
                constantsFilename: "Avalanche-Test.json"
            });
        } else if (chainId == CHAIN_ID_UNICHAIN) {
            return ChainInfo({
                evmChainId: CHAIN_ID_UNICHAIN,
                wormholeChainId: WormholeChains.CHAIN_ID_UNICHAIN,
                name: "Unichain",
                foundryAlias: "unichain",
                constantsFilename: "Unichain-Test.json"
            });
        } else if (chainId == CHAIN_ID_WORLDCHAIN) {
            return ChainInfo({
                evmChainId: CHAIN_ID_WORLDCHAIN,
                wormholeChainId: WormholeChains.CHAIN_ID_WORLDCHAIN,
                name: "Worldchain",
                foundryAlias: "worldchain",
                constantsFilename: "Worldchain-Test.json"
            });
        } else if (chainId == CHAIN_ID_MONAD) {
            return ChainInfo({
                evmChainId: CHAIN_ID_MONAD,
                wormholeChainId: WormholeChains.CHAIN_ID_MONAD,
                name: "Monad",
                foundryAlias: "monad",
                constantsFilename: "Monad-Test.json"
            });
        } else if (chainId == CHAIN_ID_PLASMA) {
            return ChainInfo({
                evmChainId: CHAIN_ID_PLASMA,
                wormholeChainId: 58,
                name: "Plasma",
                foundryAlias: "plasma",
                constantsFilename: "Plasma-Test.json"
            });
        } else if (chainId == CHAIN_ID_HYPER_EVM) {
            return ChainInfo({
                evmChainId: CHAIN_ID_HYPER_EVM,
                wormholeChainId: WormholeChains.CHAIN_ID_HYPER_E_V_M,
                name: "HyperEVM",
                foundryAlias: "hyper_evm",
                constantsFilename: "HyperEVM-Test.json"
            });
        } else {
            revert InvalidChainId();
        }
    }
}
