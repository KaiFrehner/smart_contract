# Chapter 1: Block Chain Refresher
## Transaction capacity: Anyone can initiate transactions.
Peer-to-Peer Network:
- Permissionless
- Censorship-resistant
- No special privileges
## Transaction legitimacy: Ensure transaction authenticity and integrity using cryptography
private key encrypts outgoing messages, which can be decrypted with the public key
## Transaction consensus: deciding which legitimate transaction is valid.
The network agrees on the current state of the ledger. Problem when several transactions happen at the same time: Edith:
- “I transfer all of my Ether to Lucas.”
- Edith: “I transfer all of my Ether to Daniel.”
All transaction types modify the data structure. There must be a consensus regarding
the validity and order of transactions.
consensus types: 
- Proof of Authority: a centralised party decides
- Proof of Work: validation in proportion to computational resources
- Proof of Stake: validation in proportion to collateral

# Chapter 2: Block Chain Basics
## Account based Model
Etherium uses account based model. each account has a 20 byte address in hexadecimal encoding
Externally owned accounts (controlled by a private key): 
- adress
- balance
- nonce (# number of transactions)

Contract Account (controlled by contract code):
- Adress
- Balance
- Nonce (# number of transaction)
- contract code
- contract storage

create a contrace: 
- EOA (or CA) issues (internal) transaction with zero address as recipient address.
- The transaction carries the contract code.
- Transaction confirmation = contract deployment
- New contract account address = SHA3.256(address sender, nonce)

account based model is more flexible and intuitive, but: 
- privacy concern: same address for several transactions
- while first transaction is being executed following transactions are stuck
- possible conflicts between several transactions on same account from different sources.

## Transactions
Transaction: A transaction is a message sent from an externally owned account (EOA).
Transaction modify states: (can only be modified by transaction, and each transaction must modify a state.)
- Ether balance
- Contract Account's (CA) storage

Contract Account (CA): only issues internal transactions / calls. must be triggered be an EOA initially

Call: A call is executed locally (on the node). It is read-only, i.e.,
does not lead to state changes. Not subject to network fees.

Internal Transaction: part of another transaction and must
be executed alongside the containing transaction.

Internal Call: is part of a transaction and must be executed alongside the
containing transaction. Subject to network fees.

Etherium Transations: 
always contain: 
- Recipient Address: The recipient’s hexadecimal address.
- Nonce: Transaction count from sender.
- Signature: Consisting of the variables V, R and S.
- Gas Limit: Maximum number of transaction execution steps.
- Gas Price: Fee the sender is willing to pay per execution step.
- (value: Ether valie in Wei, 10^18 Wei = 1 ETH)
- (Data: Contract execution instructions)

## Gas and Fees
In order to fix the problem of infinit loops (or resource intensive scripts) ETH transaction costs is attributed to transactions. 
Bitcoin uses limited scripting language to solve this problem. 

- Addition: 3 gas uints
- multiplication: 5 gas uints
- store 256 bits: 20k gas units
- gas limit: user sets this. maximum amount paid for transaction
- gas price: price in muETH or gwei per unit of gas

Minimum 21k gas für a ETH transaction

ETH Gas Fees after EIP-1559
- Base Fee: is burned by the network (takes ETH out of circulation). increased or decreased by 12.5% per Block. Set depending on demand for block space. 
- Priority Fee (Tip): incentivies minor to include transaction in the block.
- Max Fee: set by user = maximum willingness to pay
- Refund: max(0, maxFee - (baseFee + maxpriority fee)) unused gas is returned.

Base Fee adjustment: 
only asdjusted if gas used <> target gas
r_cur = r_pred * (1+1/8 * (s_pred - s_target)/s_target)
r_pred: base fee of previous block
s_pred: block size of previous block
s_target: target block size

BSP: 
s_pred = 30 mio
r_pred = 20 gwei
s_target = 15 mio
r_cur = 20 gwei * (1 + (1/8)* (30 mio - 15 mio)/ 15 mio) = 20 gwei *(1+1/8) 
= 20 * 9 / 8 = 22.5 gwei

## Smart Contracts and the EVM (Etherium Virtual Machine)
EVM (Etherium Virtual Machine): 
- runs on every node
- processes transactions and state changes (deterministically)
- Turing complete
- State changes as part of consensus: everyone performs all computations

Slow State Machine: EVM is 'world computer'. A slow network that executes exactly as specified and state changes can be tracked and verified by any network participant

cons of EVM
- slow
- every node processes all transactions
- Tradeoff: inclusion vs performance
-- verfication (computation resources)
-- Data exchange (network resources)
- 10 - 20 transactions per second

pros of EVM
- permissionless
- distributed -> robust
- Trustless -> verifiable
- irreversible

EVM ideal for smart contracts!

Native on-Chain Data (eg. ETH Transaction):
- stored on-chain and fully secured by consensus protocoll
- Native protocol token transactions and some endogeneous (token) contracts
- On-chain validation
Off-Chain Data(football scores or weather data):
- No native on-chain representation
- Data can be hashed
- requires trustworthy data providers (oracle)
Physical Off-Chain Reference (Shipment containers):
- No native on-chain representation
- Data cannot be hashed
- Requires trustworthy data providers (oracles) as well as reliable cryptoanchors.

# Smart Contract Programming
## Develompent Workflow
Development -> Compilation -> Deployment -> Testing


## Solidity Basics


## Functions and Modifiers
function < functionName >( < parameters >) < modifiers >
    returns ( < return variables >) {
    < function body >
}
parameters with _local

modifiers:
- Accesibility: which account can access the function of variable.
- State Permission: which function can read, write or modify a state 
-- pure: no read, no write
-- view: yes read, no write
-- <omitted>: yes read, yes write
- special and custom modifer: 
-- payable: allows a function to receive ETH as part of a transaction
-- virtual & override: used for inheritance
-- constant: no changes allowed. 
-- imutable: no changes allowed, can be set during deployment

