import { ethers } from "ethers";
import { StandardMerkleTree } from "@openzeppelin/merkle-tree";
import fs from "fs";

// arguments to pass : caliberAddress mockBaseTokenAddress mockERC4626Address mockERC4626PosId

// scripts format: [commandsHash, stateHash, stateBitmap, positionID, instructionType]

const caliberAddr = process.argv[2];
const mockBaseTokenAddr = process.argv[3];
const mockERC4626Addr = process.argv[4];
const mockERC4626PosId = process.argv[5];

const depositMock4626Script = [
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
  "0",
];

const redeemMock4626Script = [
  keccak256EncodePacked([
    ethers.concat(["0xba08765201000102ffffffff", mockERC4626Addr]),
  ]),
  keccak256EncodePacked([
    ethers.zeroPadValue(caliberAddr, 32),
    ethers.zeroPadValue(caliberAddr, 32),
  ]),
  "0x60000000000000000000000000000000",
  mockERC4626PosId,
  "0",
];

const accountingMock4626Script = [
  keccak256EncodePacked([
    ethers.concat(["0x38d52e0f02ffffffffffff00", mockERC4626Addr]),
    ethers.concat(["0x70a082310201ffffffffff01", mockERC4626Addr]),
    ethers.concat(["0x4cdad5060201ffffffffff01", mockERC4626Addr]),
  ]),
  keccak256EncodePacked([ethers.zeroPadValue(caliberAddr, 32)]),
  "0x40000000000000000000000000000000",
  mockERC4626PosId,
  "1",
];

const values = [
  depositMock4626Script,
  redeemMock4626Script,
  accountingMock4626Script,
];

const tree = StandardMerkleTree.of(values, [
  "bytes32",
  "bytes32",
  "uint128",
  "uint256",
  "uint256",
]);

const treeData = {
  root: tree.root,
  proofDepositMock4626: tree.getProof(0),
  proofRedeemMock4626: tree.getProof(1),
  proofAccountingMock4626: tree.getProof(2),
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
