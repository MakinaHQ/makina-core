// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Base} from "../../test/base/Base.sol";

abstract contract DeployCore is Base, Script {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    PriceFeedRoute[] public priceFeedRoutes;
    TokenToRegister[] public tokensToRegister;
    SwapperData[] public swappersData;

    address public dao;
    address public deployer;

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _coreSetup() public virtual {}

    function _deploySetupBefore() public {
        PriceFeedRoute[] memory _priceFeedRoutes =
            abi.decode(vm.parseJson(inputJson, ".priceFeedRoutes"), (PriceFeedRoute[]));
        for (uint256 i; i < _priceFeedRoutes.length; i++) {
            priceFeedRoutes.push(_priceFeedRoutes[i]);
        }

        TokenToRegister[] memory _tokensToRegister =
            abi.decode(vm.parseJson(inputJson, ".foreignTokens"), (TokenToRegister[]));
        for (uint256 i; i < _tokensToRegister.length; i++) {
            tokensToRegister.push(_tokensToRegister[i]);
        }

        SwapperData[] memory _swappersData = abi.decode(vm.parseJson(inputJson, ".swappersTargets"), (SwapperData[]));
        for (uint256 i; i < _swappersData.length; i++) {
            swappersData.push(_swappersData[i]);
        }

        dao = abi.decode(vm.parseJson(inputJson, ".dao"), (address));

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() public virtual {}
}
