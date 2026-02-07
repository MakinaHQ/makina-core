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

    function run() public {
        _deploySetupBefore();
        _coreSetup();
        _deploySetupAfter();
    }

    function _coreSetup() public virtual {}

    function _deploySetupBefore() public {
        superAdminRoleGrant = AMRoleGrant({
            roleId: 0,
            account: abi.decode(vm.parseJson(inputJson, ".superAdminRoleGrant.account"), (address)),
            executionDelay: abi.decode(vm.parseJson(inputJson, ".superAdminRoleGrant.executionDelay"), (uint32))
        });

        AMRoleGrant[] memory _otherRoleGrants = abi.decode(vm.parseJson(inputJson, ".otherRoleGrants"), (AMRoleGrant[]));
        for (uint256 i; i < _otherRoleGrants.length; i++) {
            otherRoleGrants.push(_otherRoleGrants[i]);
        }

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

        BridgeData[] memory _bridgesData = abi.decode(vm.parseJson(inputJson, ".bridgesTargets"), (BridgeData[]));
        for (uint256 i; i < _bridgesData.length; i++) {
            bridgesData.push(_bridgesData[i]);
        }

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() public virtual {}

    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address) {
        return _deployCodeCreateX(bytecode, salt, deployer);
    }
}
