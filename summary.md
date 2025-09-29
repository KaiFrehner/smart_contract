# Chapter 1: Block Chain Refresher
## Transaction capacity: Anyone can initiate transactions.
Peer-to-Peer Network:
- Permissionless
- Censorship-resistant
- No special privileges
## Transaction legitimacy: Ensure transaction authenticity and integrity using cryptography
private key encripts outgoing messages, which can be decrypted with the public key
## Transaction consensus: deciding which legitimate transaction is valid.
The network agrees on the current state of the ledger. Problem when several transactions happen at the same time: Edith:
- “I transfer all of my Ether to Lucas.”
- Edith: “I transfer all of my Ether to Daniel.”
All transaction types modify the data structure. There must be a consensus regarding
the validity and order of transactions.
consensus types: 
- Proof of Authotiry: a centralized party decides
- Proof of Work: validation in proportion to computational resources
- Proof of Stake: validation in proportion to collateral

# Chapter 2: Block Chain Basics
## Acount based Model
Etherium uses account based model. each account has a 20 byte address in hexidecimal encoding
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

account based modell is more flexible and intuitive, but: 
- privacy concern: same adress for several transactions
- while first transaction is being executed following transactions are stuck
- possible conflicts between several transactions on same account from diffreent sources.
