import { ethers } from "ethers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// arguments to pass : caliberAddress mockAccountingTokenAddress mockBaseTokenAddress mockERC4626Address mockPoolAddress mockERC4626PosId

// instructions format: [commandsHash, stateHash, stateBitmap, positionID, affectedTokensHash, instructionType]

const caliberAddr = process.argv[2];
const mockAccountingTokenAddr = process.argv[3];
const mockBaseTokenAddr = process.argv[4];
const mockERC4626Addr = process.argv[5];
const mockERC4626PosId = process.argv[6];
const mockPoolAddr = process.argv[7];
const mockPoolAddrPosId = process.argv[8];

const depositMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x6e553f65010102ffffffffff", mockERC4626Addr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(mockERC4626Addr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockERC4626PosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0",
];

const redeemMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0xba08765201000102ffffffff", mockERC4626Addr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(caliberAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0x60000000000000000000000000000000",
  mockERC4626PosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0",
];

const accountingMock4626Instruction = [
  keccak256EncodePacked([
    ethers.concat(["0x38d52e0f02ffffffffffff00", mockERC4626Addr]),
    ethers.concat(["0x70a082310202ffffffffff02", mockERC4626Addr]),
    ethers.concat(["0x4cdad5060202ffffffffff00", mockERC4626Addr]),
  ]),
  keccak256EncodePacked([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x20000000000000000000000000000000",
  mockERC4626PosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "1",
];

const addLiquidityMockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x095ea7b3010001ffffffffff", mockAccountingTokenAddr]),
    ethers.concat(["0x095ea7b3010002ffffffffff", mockBaseTokenAddr]),
    ethers.concat(["0x9cd441da010102ffffffffff", mockPoolAddr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(mockPoolAddr, 32),
  ]),
  "0x80000000000000000000000000000000",
  mockPoolAddrPosId,
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
  keccak256EncodePacked([
    ethers.zeroPadValue(mockPoolAddr, 32),
    ethers.zeroPadValue(mockAccountingTokenAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockAccountingTokenAddr, 32),
  ]),
  "0",
];

const removeLiquidityOneSide1MockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0xdf7aebb9010001ffffffffff", mockPoolAddr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0x40000000000000000000000000000000",
  mockPoolAddrPosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "0",
];

const accountingMockPoolInstruction = [
  keccak256EncodePacked([
    ethers.concat(["0x70a082310202ffffffffff02", mockPoolAddr]),
    ethers.concat(["0xeeb47144020200ffffffff00", mockPoolAddr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0xa0000000000000000000000000000000",
  mockPoolAddrPosId,
  keccak256EncodePacked([
    ethers.zeroPadValue(mockBaseTokenAddr, 32),
  ]),
  "1",
];

const values = [
  depositMock4626Instruction,
  redeemMock4626Instruction,
  accountingMock4626Instruction,
  addLiquidityMockPoolInstruction,
  addLiquidityOneSide0MockPoolInstruction,
  removeLiquidityOneSide1MockPoolInstruction,
  accountingMockPoolInstruction,
];

const tree = StandardMerkleTree.of(values, [
  "bytes32",
  "bytes32",
  "uint128",
  "uint256",
  "bytes32",
  "uint256",
]);

const treeData = {
  root: tree.root,
  proofDepositMock4626: tree.getProof(0),
  proofRedeemMock4626: tree.getProof(1),
  proofAccountingMock4626: tree.getProof(2),
  proofAddLiquidityMockPool: tree.getProof(3),
  proofAddLiquidityOneSide0MockPool: tree.getProof(4),
  proofRemoveLiquidityOneSide1MockPool: tree.getProof(5),
  proofAccountingMockPool: tree.getProof(6),
};

fs.writeFileSync(
  "script/merkle/merkleTreeData.json",
  JSON.stringify(treeData, null, 2) + "\n",
);

function keccak256EncodePacked(commands) {
  return commands.length > 0
    ? ethers.keccak256(ethers.concat(commands))
    : ethers.ZeroHash;
}
