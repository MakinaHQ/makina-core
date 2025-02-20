// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/StdJson.sol";
import "test/Base.sol";
import {ISwapper} from "../src/interfaces/ISwapper.sol";

abstract contract DeployMakinaCoreShared is Base {
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
    string public inputPath;
    string public outputPath;

    string public constantsFilename;
    string public outputFilename;

    string public jsonConstants;

    PriceFeedData[] public priceFeedData;
    DexAggregatorData[] public dexAggregatorsData;

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _coreSetup() public virtual {}

    function _deploySetupBefore() public {
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

    function _deploySetupAfter() public virtual {}

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
