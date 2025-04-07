## Makina Core Specifications

## Protocol

### Machine

The `Machine` contract is the central and user-facing component of the protocol. It handles deposits, redemptions and share price calculation.

### Caliber

The `Caliber` contract serves as the execution engine, responsible for deploying assets to external protocols. On the hub chain, the Machine communicates directly with its associated hub Caliber. Additional Caliber instances can be deployed on spoke chains to expand the protocol across networks.

#### Mailbox

Cross-chain communication between the hub Machine and spoke Calibers is facilitated through `CaliberMailbox` contracts. Each spoke Caliber is deployed alongside a `CaliberMailbox` on its respective spoke chain. These mailbox contracts enable spoke Calibers to communicate asynchronously with the hub Machine, coordinating and tracking cross-chain fund transfers initiated or received by the Caliber.

#### Instructions

Calibers can manage and account for positions by executing authorized instructions, which leverage the Weiroll command-chaining framework. A large set of instructions can be pre-approved and registered in a Merkle Tree, whose root is stored in the caliber and used to verify authorization proof.

#### Standard Operations:

- Can add a base token with `addBaseToken()`.
- Can remove a base token with `removeBaseToken()`.
- Can account for a position with `accountForPosition()`.
- Can account for several positions in a batch with `accountForPositionBatch()`.
- Can fetch net caliber aum and positions detail with `getDetailedAum()`.
- Can open, manage and close a position with `managePosition()`.
- Can swap a token into any base token with `swap()`.

### SwapModule

The `SwapModule` contract serves as an external module, enabling calibers and machines to securely interact with external swap protocols using unverified calldata. The swapModule pulls funds from caller before execution and sends back output funds upon completion.

### Oracle Registry

The `OracleRegistry` contract acts as an aggregator of Chainlink price feeds, and prices tokens in a reference currency (e.g. USD) using either one feed or a two feeds path.

### Chain Registry

The protocol uses Wormhole cross-chain queries to relay accounting data from spoke Calibers to the hub Machine. Since Wormhole relies on its own custom chain ID system, the `ChainRegistry` contract provides a mapping between standard EVM chain IDs and Wormhole chain IDs.

### Token Registry

The `TokenRegistry` contract maintains the association between token addresses on the hub and spoke chains. It enables consistent identification and pricing of bridged assets across networks, ensuring accurate cross-chain accounting.

### Access Control

Contracts in this repository implement the [OpenZeppelin AccessManager](https://docs.openzeppelin.com/contracts/5.x/api/access#accessmanager). The Makina protocol provides an instance of `AccessManager` with addresses defined by the Makina DAO, but institutions that require it can deploy machines with their own `AccessManager`. See [PERMISSIONS.md](https://github.com/makinaHQ/makina-core/blob/main/PERMISSIONS.md) for full list of permissions.

Roles use in makina core contracts are defined as follows:

- `ADMIN_ROLE` - roleId `0` - the Access Manager super admin. Can grant and revoke any role. Set by default in the Access Manager constructor.
