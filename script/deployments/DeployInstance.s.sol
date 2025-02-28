// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

abstract contract DeployInstance is Script {
    string public outputPath;

    string public paramsJson;
    string internal coreOutputJson;

    address public deployedInstance;
}
