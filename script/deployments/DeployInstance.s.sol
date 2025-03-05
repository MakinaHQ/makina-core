// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";

abstract contract DeployInstance is Script {
    string public outputPath;

    string public paramsJson;
    string internal coreOutputJson;

    address public deployedInstance;
}
