import { ethers } from "ethers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// arguments to pass : caliberAddr mockAccountingTokenAddr mockBaseTokenAddr mockERC4626Addr mockSupplyModuleAddr mockSupplyModulePosId mockBorrowModuleAddr mockBorrowModulePosId mockPoolAddr mockERC4626PosId

// instructions format: [commandsHash, stateHash, stateBitmap, positionId, affectedTokensHash, instructionType]

const caliberAddr = process.argv[2];
const mockAccountingTokenAddr = process.argv[3];
const mockBaseTokenAddr = process.argv[4];
const mockERC4626Addr = process.argv[5];
const mockERC4626PosId = process.argv[6];
const mockSupplyModuleAddr = process.argv[7];
const mockSupplyModulePosId = process.argv[8];
const mockBorrowModuleAddr = process.argv[9];
const mockBorrowModulePosId = process.argv[10];
const mockPoolAddr = process.argv[11];
const mockPoolAddrPosId = process.argv[12];

const depositMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x6e553f65010102ffffffffff", mockERC4626Addr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockERC4626Addr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockERC4626PosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const redeemMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0xba08765201000102ffffffff", mockERC4626Addr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(caliberAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0x60000000000000000000000000000000",
  mockERC4626PosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const accountingMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x38d52e0f02ffffffffffff00", mockERC4626Addr]),
    ethers.concat(["0x70a082310202ffffffffff02", mockERC4626Addr]),
    ethers.concat(["0x4cdad5060202ffffffffff00", mockERC4626Addr]),
  ]),
  getStateHash([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x20000000000000000000000000000000",
  mockERC4626PosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "1",
];

const supplyMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x354030230101ffffffffffff", mockSupplyModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockSupplyModuleAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const withdrawMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x2e1a7d4d0100ffffffffffff", mockSupplyModuleAddr]),
  ]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const accountingMockSupplyModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x1aefb1070200ffffffffff00", mockSupplyModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockSupplyModulePosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "1",
];

const borrowMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xc5ebeaec0100ffffffffffff", mockBorrowModuleAddr]),
  ]),
  getStateHash([]),
  "0x00000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const repayMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x371fd8e60101ffffffffffff", mockBorrowModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockBorrowModuleAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const accountingMockBorrowModuleInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xd283e75f0200ffffffffff00", mockBorrowModuleAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockBorrowModulePosId,
  true,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "1",
];

const addLiquidityMockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockAccountingTokenAddr]),
    ethers.concat(["0x095ea7b3010002ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x9cd441da010102ffffffffff", mockPoolAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockPoolAddr, 32)]),
  "0x80000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockAccountingTokenAddr, 32),
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0",
];

const addLiquidityOneSide0MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockAccountingTokenAddr]),
    ethers.concat(["0x8e022364010102ffffffffff", mockPoolAddr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockPoolAddr, 32),
    ethers.zeroPadValue(mockAccountingTokenAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockAccountingTokenAddr, 32)]),
  "0",
];

const addLiquidityOneSide1MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x8e022364010102ffffffffff", mockPoolAddr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockPoolAddr, 32),
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const removeLiquidityOneSide0MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xdf7aebb9010001ffffffffff", mockPoolAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockAccountingTokenAddr, 32)]),
  "0x40000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockAccountingTokenAddr, 32)]),
  "0",
];

const removeLiquidityOneSide1MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xdf7aebb9010001ffffffffff", mockPoolAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0x40000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "0",
];

const accounting0MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x70a082310202ffffffffff02", mockPoolAddr]),
    ethers.concat(["0xeeb47144020200ffffffff00", mockPoolAddr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockAccountingTokenAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockAccountingTokenAddr, 32)]),
  "1",
];

const accounting1MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x70a082310202ffffffffff02", mockPoolAddr]),
    ethers.concat(["0xeeb47144020200ffffffff00", mockPoolAddr]),
  ]),
  getStateHash([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  false,
  keccak256EncodePacked([ethers.zeroPadValue(mockBaseTokenAddr, 32)]),
  "1",
];

const harvestMockBaseTokenInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x40c10f19010001ffffffffff", mockBaseTokenAddr]),
  ]),
  getStateHash([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x80000000000000000000000000000000",
  0,
  false,
  keccak256EncodePacked([]),
  "2",
];

const values = [
  depositMock4626Instruction,
  redeemMock4626Instruction,
  accountingMock4626Instruction,
  supplyMockSupplyModuleInstruction,
  withdrawMockSupplyModuleInstruction,
  accountingMockSupplyModuleInstruction,
  borrowMockBorrowModuleInstruction,
  repayMockBorrowModuleInstruction,
  accountingMockBorrowModuleInstruction,
  addLiquidityMockPoolInstruction,
  addLiquidityOneSide0MockPoolInstruction,
  addLiquidityOneSide1MockPoolInstruction,
  removeLiquidityOneSide0MockPoolInstruction,
  removeLiquidityOneSide1MockPoolInstruction,
  accounting0MockPoolInstruction,
  accounting1MockPoolInstruction,
  harvestMockBaseTokenInstruction,
];

const tree = StandardMerkleTree.of(values, [
  "bytes32",
  "bytes32",
  "uint128",
  "uint256",
  "bool",
  "bytes32",
  "uint256",
]);

const treeData = {
  root: tree.root,
  proofDepositMock4626: tree.getProof(0),
  proofRedeemMock4626: tree.getProof(1),
  proofAccountingMock4626: tree.getProof(2),
  proofSupplyMockSupplyModule: tree.getProof(3),
  proofWithdrawMockSupplyModule: tree.getProof(4),
  proofAccountingMockSupplyModule: tree.getProof(5),
  proofBorrowMockBorrowModule: tree.getProof(6),
  proofRepayMockBorrowModule: tree.getProof(7),
  proofAccountingMockBorrowModule: tree.getProof(8),
  proofAddLiquidityMockPool: tree.getProof(9),
  proofAddLiquidityOneSide0MockPool: tree.getProof(10),
  proofAddLiquidityOneSide1MockPool: tree.getProof(11),
  proofRemoveLiquidityOneSide0MockPool: tree.getProof(12),
  proofRemoveLiquidityOneSide1MockPool: tree.getProof(13),
  proofAccounting0MockPool: tree.getProof(14),
  proofAccounting1MockPool: tree.getProof(15),
  proofHarvestMockBaseToken: tree.getProof(16),
};

fs.writeFileSync(
  "script/merkle/merkleTreeData.json",
  JSON.stringify(treeData, null, 2) + "\n",
);

function keccak256EncodePacked(list) {
  return ethers.keccak256(ethers.concat(list));
}

function getStateHash(state) {
  return state.length > 0 ? keccak256EncodePacked(state) : ethers.ZeroHash;
}
