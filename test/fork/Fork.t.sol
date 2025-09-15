// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {Constants} from "../utils/Constants.sol";
import {ChainsInfo} from "../utils/ChainsInfo.sol";

import {Base} from "../base/Base.sol";

abstract contract Fork_Test is Base, Test, Constants {
    uint256 public hubChainId;
    uint256[] public spokeChainIds;

    HubCore public hubCore;
    mapping(uint256 spokeChainId => SpokeCore spokeCore) public spokeCores;

    mapping(uint256 chainId => ForkData forkData) public forksData;

    struct ForkData {
        // fork id
        uint256 forkId;
        // tokens
        address usdc;
        address weth;
        // governance
        address dao;
        address mechanic;
        address securityCouncil;
    }

    function _setUp() public {
        _setupChain(hubChainId);

        for (uint256 i = 0; i < spokeChainIds.length; i++) {
            _setupChain(spokeChainIds[i]);
        }
    }

    function _setupChain(uint256 chainId) internal {
        ForkData storage forkData = forksData[chainId];

        ChainsInfo.ChainInfo memory chainInfo = ChainsInfo.getChainInfo(chainId);

        // create and select fork
        forkData.forkId = vm.createSelectFork({urlOrAlias: chainInfo.foundryAlias});

        string memory inputPath = string.concat(vm.projectRoot(), "/test/fork/constants/");
        string memory inputJson = vm.readFile(string.concat(inputPath, chainInfo.constantsFilename));

        // read misc addresses from json
        forkData.dao = abi.decode(vm.parseJson(inputJson, ".dao"), (address));
        forkData.mechanic = abi.decode(vm.parseJson(inputJson, ".mechanic"), (address));
        forkData.securityCouncil = abi.decode(vm.parseJson(inputJson, ".securityCouncil"), (address));
        forkData.usdc = abi.decode(vm.parseJson(inputJson, ".usdc"), (address));
        forkData.weth = abi.decode(vm.parseJson(inputJson, ".weth"), (address));

        bool isHub = chainId == hubChainId;

        // deploy core contracts
        if (isHub) {
            address wormhole = abi.decode(vm.parseJson(inputJson, ".wormhole"), (address));
            hubCore = deployHubCore(address(this), forkData.dao, wormhole);
        } else {
            spokeCores[chainId] = deploySpokeCore(address(this), forkData.dao, hubChainId);
        }

        // setup makina registry and chain registry
        if (isHub) {
            setupHubCoreRegistry(hubCore);
            uint256[] memory evmChainIds = abi.decode(vm.parseJson(inputJson, ".supportedChains"), (uint256[]));
            setupChainRegistry(hubCore.chainRegistry, evmChainIds);
        } else {
            setupSpokeCoreRegistry(spokeCores[chainId]);
        }

        // setup oracle registry
        PriceFeedRoute[] memory priceFeedRoutes =
            abi.decode(vm.parseJson(inputJson, ".priceFeedRoutes"), (PriceFeedRoute[]));
        setupOracleRegistry(isHub ? hubCore.oracleRegistry : spokeCores[chainId].oracleRegistry, priceFeedRoutes);

        // setup swapModule
        SwapperData[] memory swappersData = abi.decode(vm.parseJson(inputJson, ".swappersTargets"), (SwapperData[]));
        setupSwapModule(isHub ? hubCore.swapModule : spokeCores[chainId].swapModule, swappersData);

        // setup access manager
        if (isHub) {
            setupHubCoreAMFunctionRoles(hubCore);
            setupAccessManagerRoles(hubCore.accessManager, forkData.dao, address(this));
        } else {
            setupSpokeCoreAMFunctionRoles(spokeCores[chainId]);
            setupAccessManagerRoles(spokeCores[chainId].accessManager, forkData.dao, address(this));
        }
    }
}
