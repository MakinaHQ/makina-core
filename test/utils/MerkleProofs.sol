// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {stdJson} from "forge-std/StdJson.sol";
import {Vm} from "forge-std/Vm.sol";

library MerkleProofs {
    using stdJson for string;

    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    struct MerkleTreeParams {
        address caliber;
        address mockAccountingToken;
        address mockBaseToken;
        address mockVault;
        uint256 mockVaultPosId;
        address mockSupplyModule;
        uint256 mockSupplyModulePosId;
        address mockBorrowModule;
        uint256 mockBorrowModulePosId;
        address mockPool;
        uint256 mockPoolPosId;
        address mockFlashLoanModule;
        uint256 mockLoopPosId;
        uint256 lendingMarketPosGroupId;
    }

    function _generateMerkleData(MerkleTreeParams memory params) internal {
        string[] memory command = new string[](16);
        command[0] = "yarn";
        command[1] = "genMerkleDataMock";
        command[2] = vm.toString(params.caliber);
        command[3] = vm.toString(params.mockAccountingToken);
        command[4] = vm.toString(params.mockBaseToken);
        command[5] = vm.toString(params.mockVault);
        command[6] = vm.toString(params.mockVaultPosId);
        command[7] = vm.toString(params.mockSupplyModule);
        command[8] = vm.toString(params.mockSupplyModulePosId);
        command[9] = vm.toString(params.mockBorrowModule);
        command[10] = vm.toString(params.mockBorrowModulePosId);
        command[11] = vm.toString(params.mockPool);
        command[12] = vm.toString(params.mockPoolPosId);
        command[13] = vm.toString(params.mockFlashLoanModule);
        command[14] = vm.toString(params.mockLoopPosId);
        command[15] = vm.toString(params.lendingMarketPosGroupId);
        vm.ffi(command);
    }

    function _getMerkleData() internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/script/merkle/merkleTreeData.json"));
    }

    function _getAllowedInstrMerkleRoot() internal view returns (bytes32) {
        return _getMerkleData().readBytes32(".root");
    }

    function _getDeposit4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDepositMock4626");
    }

    function _getRedeem4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRedeemMock4626");
    }

    function _getAccounting4626InstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMock4626");
    }

    function _getSupplyMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofSupplyMockSupplyModule");
    }

    function _getWithdrawMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofWithdrawMockSupplyModule");
    }

    function _getAccountingMockSupplyModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockSupplyModule");
    }

    function _getBorrowMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofBorrowMockBorrowModule");
    }

    function _getRepayMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRepayMockBorrowModule");
    }

    function _getAccountingMockBorrowModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockBorrowModule");
    }

    function _getAddLiquidityMockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityMockPool");
    }

    function _getAddLiquidityOneSide0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityOneSide0MockPool");
    }

    function _getAddLiquidityOneSide1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAddLiquidityOneSide1MockPool");
    }

    function _getRemoveLiquidityOneSide0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRemoveLiquidityOneSide0MockPool");
    }

    function _getRemoveLiquidityOneSide1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofRemoveLiquidityOneSide1MockPool");
    }

    function _getAccounting0MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccounting0MockPool");
    }

    function _getAccounting1MockPoolInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccounting1MockPool");
    }

    function _getHarvestMockBaseTokenInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofHarvestMockBaseToken");
    }

    function _getDummyLoopMockFlashLoanModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDummyLoopMockFlashLoanModule");
    }

    function _getAccountingMockFlashLoanModuleInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofAccountingMockFlashLoanModule");
    }

    function _getManageFlashLoanDummyInstrProof() internal view returns (bytes32[] memory) {
        return _getMerkleData().readBytes32Array(".proofDummyManageFlashLoan");
    }
}
