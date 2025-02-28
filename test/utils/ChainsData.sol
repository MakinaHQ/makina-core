// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.28;

library ChainsData {
    error InvalidChainId();

    struct ChainData {
        uint256 chainId;
        string name;
        string foundryAlias;
        string constantsFilename;
    }

    uint256 constant CHAIN_ID_ETHEREUM = 1;
    uint256 constant CHAIN_ID_ETHEREUM_SEPOLIA = 11155111;
    uint256 constant CHAIN_ID_BASE = 8453;
    uint256 constant CHAIN_ID_BASE_SEPOLIA = 84532;
    uint256 constant CHAIN_ID_INK = 57073;
    uint256 constant CHAIN_ID_INK_SEPOLIA = 763373;

    function getChainData(uint256 chainId) internal pure returns (ChainData memory) {
        if (chainId == CHAIN_ID_ETHEREUM) {
            return ChainData({
                chainId: CHAIN_ID_ETHEREUM,
                name: "Ethereum",
                foundryAlias: "mainnet",
                constantsFilename: "Mainnet-Test.json"
            });
        } else if (chainId == CHAIN_ID_ETHEREUM_SEPOLIA) {
            return ChainData({
                chainId: CHAIN_ID_ETHEREUM_SEPOLIA,
                name: "Sepolia",
                foundryAlias: "sepolia",
                constantsFilename: "Sepolia-Test.json"
            });
        } else if (chainId == CHAIN_ID_BASE) {
            return ChainData({
                chainId: CHAIN_ID_BASE,
                name: "Base",
                foundryAlias: "base",
                constantsFilename: "Base-Test.json"
            });
        } else if (chainId == CHAIN_ID_BASE_SEPOLIA) {
            return ChainData({
                chainId: CHAIN_ID_BASE_SEPOLIA,
                name: "Base Sepolia",
                foundryAlias: "base_sepolia",
                constantsFilename: "BaseSepolia-Test.json"
            });
        } else if (chainId == CHAIN_ID_INK) {
            return
                ChainData({chainId: CHAIN_ID_INK, name: "Ink", foundryAlias: "ink", constantsFilename: "Ink-Test.json"});
        } else if (chainId == CHAIN_ID_INK_SEPOLIA) {
            return ChainData({
                chainId: CHAIN_ID_INK_SEPOLIA,
                name: "Ink Sepolia",
                foundryAlias: "ink_sepolia",
                constantsFilename: "InkSepolia-Test.json"
            });
        } else {
            revert InvalidChainId();
        }
    }
}
