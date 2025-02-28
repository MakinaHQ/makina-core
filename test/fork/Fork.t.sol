// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {IWormhole} from "@wormhole/sdk/interfaces/IWormhole.sol";

import {ChainsData} from "../utils/ChainsData.sol";

import {Base} from "../base/Base.sol";

abstract contract Fork_Test is Base, Test {
    uint256 hubChainId;
    uint256[] public spokeChainIds;

    HubFork public hubFork;
    mapping(uint256 chainId => SpokeFork spokeForkData) public spokeForks;

    struct HubFork {
        uint256 forkId;
        address dao;
        address mechanic;
        address securityCouncil;
        IWormhole wormhole;
        HubCore deployment;
    }

    struct SpokeFork {
        uint256 forkId;
        address dao;
        address mechanic;
        address securityCouncil;
        SpokeCore deployment;
    }

    function _setUp() public {
        _setupHub();

        for (uint256 i = 0; i < spokeChainIds.length; i++) {
            _setupSpoke(spokeChainIds[i]);
        }
    }

    function _setupHub() internal {
        ChainsData.ChainData memory chainData = ChainsData.getChainData(hubChainId);
        hubFork.forkId = vm.createSelectFork({urlOrAlias: chainData.foundryAlias});

        string memory paramsPath = string.concat(vm.projectRoot(), "/script/constants/");
        paramsPath = string.concat(paramsPath, "hub-core-params/");
        string memory paramsJson = vm.readFile(string.concat(paramsPath, chainData.constantsFilename));

        hubFork.dao = abi.decode(vm.parseJson(paramsJson, ".dao"), (address));
        hubFork.wormhole = abi.decode(vm.parseJson(paramsJson, ".wormhole"), (IWormhole));

        // deploy core contracts
        hubFork.deployment = deployHubCore(address(this), hubFork.dao, address(hubFork.wormhole));

        // setup hub registry
        setupHubRegistry(hubFork.deployment);

        // setup oracle registry
        PriceFeedData[] memory priceFeedData = abi.decode(vm.parseJson(paramsJson, ".priceFeedData"), (PriceFeedData[]));
        setupOracleRegistry(hubFork.deployment.oracleRegistry, priceFeedData);

        // setup swapper
        DexAggregatorData[] memory dexAggregatorsData =
            abi.decode(vm.parseJson(paramsJson, ".dexAggregatorsTargets"), (DexAggregatorData[]));
        setupSwapper(hubFork.deployment.swapper, dexAggregatorsData);

        // setup access manager
        setupAccessManager(hubFork.deployment.accessManager, hubFork.dao);
    }

    function _setupSpoke(uint256 chainId) internal {
        SpokeFork storage spokeFork = spokeForks[chainId];

        ChainsData.ChainData memory chainData = ChainsData.getChainData(chainId);
        spokeFork.forkId = vm.createSelectFork({urlOrAlias: chainData.foundryAlias});

        string memory paramsPath = string.concat(vm.projectRoot(), "/script/constants/");
        paramsPath = string.concat(paramsPath, "spoke-core-params/");
        string memory paramsJson = vm.readFile(string.concat(paramsPath, chainData.constantsFilename));

        spokeFork.dao = abi.decode(vm.parseJson(paramsJson, ".dao"), (address));

        // deploy core contracts
        spokeFork.deployment = deploySpokeCore(address(this), spokeFork.dao, hubChainId);

        // setup spoke registry
        setupSpokeRegistry(spokeFork.deployment);

        // setup oracle registry
        PriceFeedData[] memory priceFeedData = abi.decode(vm.parseJson(paramsJson, ".priceFeedData"), (PriceFeedData[]));
        setupOracleRegistry(spokeFork.deployment.oracleRegistry, priceFeedData);

        // setup swapper
        DexAggregatorData[] memory dexAggregatorsData =
            abi.decode(vm.parseJson(paramsJson, ".dexAggregatorsTargets"), (DexAggregatorData[]));
        setupSwapper(spokeFork.deployment.swapper, dexAggregatorsData);

        // setup access manager
        setupAccessManager(spokeFork.deployment.accessManager, spokeFork.dao);
    }
}
