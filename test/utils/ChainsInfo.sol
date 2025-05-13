// SPDX-License-Identifier: Unlicense
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
        } else {
            revert InvalidChainId();
        }
    }
}
