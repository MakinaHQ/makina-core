// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {CreateXUtils, ICreateXMinimal} from "./utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

abstract contract DeployCore is Base, Script, CreateXUtils {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    PriceFeedRoute[] public priceFeedRoutes;
    TokenToRegister[] public tokensToRegister;
    SwapperData[] public swappersData;
    BridgeData[] public bridgesData;

    address public deployer;
    address public upgradeAdmin;
    address public superAdmin;
    address public infraSetupAdmin;
    address public stratDeployAdmin;
    address public stratCompSetupAdmin;
    address public stratMgmtSetupAdmin;

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

        BridgeData[] memory _bridgesData = abi.decode(vm.parseJson(inputJson, ".bridgesTargets"), (BridgeData[]));
        for (uint256 i; i < _bridgesData.length; i++) {
            bridgesData.push(_bridgesData[i]);
        }

        upgradeAdmin = abi.decode(vm.parseJson(inputJson, ".upgradeAdmin"), (address));
        superAdmin = abi.decode(vm.parseJson(inputJson, ".superAdmin"), (address));
        infraSetupAdmin = abi.decode(vm.parseJson(inputJson, ".infraSetupAdmin"), (address));
        stratDeployAdmin = abi.decode(vm.parseJson(inputJson, ".stratDeployAdmin"), (address));
        stratCompSetupAdmin = abi.decode(vm.parseJson(inputJson, ".stratCompSetupAdmin"), (address));
        stratMgmtSetupAdmin = abi.decode(vm.parseJson(inputJson, ".stratMgmtSetupAdmin"), (address));

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();
    }

    function _deploySetupAfter() public virtual {}

    function _deployCode(bytes memory bytecode, bytes32 salt) internal virtual override returns (address) {
        if (salt == 0) {
            return ICreateXMinimal(CREATE_X_DEPLOYER).deployCreate2(bytecode);
        }

        bytes32 formattedSalt = _formatSalt(salt, deployer);

        return ICreateXMinimal(CREATE_X_DEPLOYER).deployCreate3(formattedSalt, bytecode);
    }
}
