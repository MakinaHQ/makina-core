// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Base} from "test/base/Base.sol";

abstract contract DeployCore is Base, Script {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    PriceFeedData[] public priceFeedData;
    DexAggregatorData[] public dexAggregatorsData;

    address public dao;
    address public deployer;

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _coreSetup() public virtual {}

    function _deploySetupBefore() public {
        PriceFeedData[] memory _priceFeedData = abi.decode(vm.parseJson(inputJson, ".priceFeedData"), (PriceFeedData[]));
        for (uint256 i; i < _priceFeedData.length; i++) {
            priceFeedData.push(_priceFeedData[i]);
        }

        DexAggregatorData[] memory _dexAggregatorsData =
            abi.decode(vm.parseJson(inputJson, ".dexAggregatorsTargets"), (DexAggregatorData[]));
        for (uint256 i; i < _dexAggregatorsData.length; i++) {
            dexAggregatorsData.push(_dexAggregatorsData[i]);
        }

        dao = abi.decode(vm.parseJson(inputJson, ".dao"), (address));

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() public virtual {}
}
