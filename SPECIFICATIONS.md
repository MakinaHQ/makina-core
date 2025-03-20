## Makina Core Specifications

## Protocol

### Machine

The `Machine` contract is the central and user-facing component of the protocol. It handles deposits, redemptions and share price calculation.

### Caliber

The `Caliber` contract is the execution engine from which assets are deployed to external protocols.

### Mailboxes

Data passing and fund transfers between calibers and machines is managed by mailboxes.

- For hub calibers, a single `HubDualMailbox` is used to handle communication between a machine and a caliber.
- For spoke calibers, a `SpokeMachineMailbox` (deployed on the hub chain) communicates with an associated `SpokeCaliberMailbox` (deployed on the same spoke chain as their associated caliber) via bridging of message and funds.

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

### Access Control

Contracts in this repository implement the [OpenZeppelin AccessManager](https://docs.openzeppelin.com/contracts/5.x/api/access#accessmanager). The Makina protocol provides an instance of `AccessManager` with addresses defined by the Makina DAO, but institutions that require it can deploy machines with their own `AccessManager`. See [PERMISSIONS.md](https://github.com/makinaHQ/makina-core/blob/main/PERMISSIONS.md) for full list of permissions.

Roles use in makina core contracts are defined as follows:

- `ADMIN_ROLE` - roleId `0` - the Access Manager super admin. Can grant and revoke any role. Set by default in the Access Manager constructor.
