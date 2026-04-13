// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {CreateXUtils} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

abstract contract DeployCore is Base, Script, CreateXUtils {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    AMRoleGrant public superAdminRoleGrant;
    AMRoleGrant[] public otherRoleGrants;
    PriceFeedRoute[] public priceFeedRoutes;
    TokenToRegister[] public tokensToRegister;
    SwapperData[] public swappersData;
    BridgeData[] public bridgesData;

    address public deployer;

    bool public skipAMSetup;

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function setSkipAMSetup(bool _skip) public {
        skipAMSetup = _skip;
    }

    function _coreSetup() internal virtual {}

    function _deploySetupBefore() internal {
        superAdminRoleGrant = AMRoleGrant({
            roleId: 0,
            account: vm.parseJsonAddress(inputJson, ".superAdminRoleGrant.account"),
            executionDelay: uint32(vm.parseJsonUint(inputJson, ".superAdminRoleGrant.executionDelay"))
        });

        AMRoleGrant[] memory _otherRoleGrants = parseAMRoleGrants(inputJson, ".otherRoleGrants");
        for (uint256 i; i < _otherRoleGrants.length; ++i) {
            otherRoleGrants.push(_otherRoleGrants[i]);
        }

        PriceFeedRoute[] memory _priceFeedRoutes = parsePriceFeedRoutes(inputJson, ".priceFeedRoutes");
        for (uint256 i; i < _priceFeedRoutes.length; ++i) {
            priceFeedRoutes.push(_priceFeedRoutes[i]);
        }

        TokenToRegister[] memory _tokensToRegister = parseTokensToRegister(inputJson, ".foreignTokens");
        for (uint256 i; i < _tokensToRegister.length; ++i) {
            tokensToRegister.push(_tokensToRegister[i]);
        }

        SwapperData[] memory _swappersData = parseSwappersData(inputJson, ".swappersTargets");
        for (uint256 i; i < _swappersData.length; ++i) {
            swappersData.push(_swappersData[i]);
        }

        BridgeData[] memory _bridgesData = parseBridgesData(inputJson, ".bridgesTargets");
        for (uint256 i; i < _bridgesData.length; ++i) {
            bridgesData.push(_bridgesData[i]);
        }

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() internal virtual {}

    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address) {
        return _deployCodeCreateX(bytecode, salt, deployer);
    }
}
