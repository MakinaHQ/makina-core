// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/StdJson.sol";
import "../test/Base.sol";
import {ISwapper} from "../src/interfaces/ISwapper.sol";

contract DeployMakinaCore is Base {
    using stdJson for string;

    struct PriceFeedData {
        address feed1;
        address feed2;
        uint256 stalenessThreshold1;
        uint256 stalenessThreshold2;
        address token;
    }

    struct DexAggregatorData {
        ISwapper.DexAggregator aggregatorId;
        address approvalTarget;
        address executionTarget;
    }

    string public basePath;
    string public path;

    string public constantsFilename = vm.envString("CONSTANTS_FILENAME");
    string public outputFilename = vm.envString("OUTPUT_FILENAME");

    string public jsonConstants;

    PriceFeedData[] public priceFeedData;
    DexAggregatorData[] public dexAggregatorsData;

    constructor() {
        string memory root = vm.projectRoot();
        basePath = string.concat(root, "/script/constants/");

        // load constants
        path = string.concat(basePath, constantsFilename);
        jsonConstants = vm.readFile(path);
    }

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _deploySetupBefore() public {
        // Loading output and use output path to later save deployed contracts
        path = string.concat(basePath, "output/");
        path = string.concat(path, "DeployMakinaCore-");
        path = string.concat(path, outputFilename);

        PriceFeedData[] memory _priceFeedData =
            abi.decode(vm.parseJson(jsonConstants, ".priceFeedData"), (PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            priceFeedData.push(_priceFeedData[i]);
        }

        DexAggregatorData[] memory _dexAggregatorsData =
            abi.decode(vm.parseJson(jsonConstants, ".dexAggregatorsTargets"), (DexAggregatorData[]));
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            dexAggregatorsData.push(_dexAggregatorsData[i]);
        }

        dao = abi.decode(vm.parseJson(jsonConstants, ".dao"), (address));

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() public {
        _setupHubRegistry();
        _setupOracleRegistry();
        _setupSwapper();

        // @TODO setup access manager

        // finish broadcasting transactions
        vm.stopBroadcast();

        string memory key = "key-deploy-makina-core-output-file";

        // write to file;
        vm.writeJson(vm.serializeAddress(key, "AccessManager", address(accessManager)), path);
        vm.writeJson(vm.serializeAddress(key, "CaliberBeacon", address(caliberBeacon)), path);
        vm.writeJson(vm.serializeAddress(key, "CaliberFactory", address(caliberFactory)), path);
        vm.writeJson(vm.serializeAddress(key, "CaliberInboxBeacon", address(caliberInboxBeacon)), path);
        vm.writeJson(vm.serializeAddress(key, "HubRegistry", address(hubRegistry)), path);
        vm.writeJson(vm.serializeAddress(key, "OracleRegistry", address(oracleRegistry)), path);
        vm.writeJson(vm.serializeAddress(key, "Swapper", address(swapper)), path);
    }

    function _setupHubRegistry() public {
        hubRegistry.setCaliberBeacon(address(caliberBeacon));
        hubRegistry.setCaliberInboxBeacon(address(caliberInboxBeacon));
        hubRegistry.setCaliberFactory(address(caliberFactory));
    }

    function _setupOracleRegistry() public {
        for (uint256 i; i < priceFeedData.length; i++) {
            oracleRegistry.setTokenFeedData(
                priceFeedData[i].token,
                priceFeedData[i].feed1,
                priceFeedData[i].stalenessThreshold1,
                priceFeedData[i].feed2,
                priceFeedData[i].stalenessThreshold2
            );
        }
    }

    function _setupSwapper() public {
        for (uint256 i; i < dexAggregatorsData.length; i++) {
            swapper.setDexAggregatorTargets(
                dexAggregatorsData[i].aggregatorId,
                dexAggregatorsData[i].approvalTarget,
                dexAggregatorsData[i].executionTarget
            );
        }
    }
}
