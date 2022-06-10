# Design Documentation

- [ERC20 Bridge](#erc20-bridge)
  - [ERC20 Bridge Deposit](#erc20-bridge-deposit)
  - [ERC20 Bridge Withdrawal](#erc20-bridge-withdrawal)

This document defines the high level bridge implementation.

## ERC20 Bridge

The ERC20 bridge facilitates the transfer of ERC20 tokens from Ethereum to be represented as tokens on Fuel.

## ERC20 Bridge Deposit

1. User starts a deposit by calling deposit (has already approved token transfer to L1ERC20Gateway)
1. L1ERC20Gateway transfers tokens to itself to custody while bridged
1. L1ERC20Gateway creates a message in the FuelMessageOutbox to be relayed on Fuel with the ERC20GatewayDepositPredicate so that anyone can spend the MessageInput on a user's behalf but with guarantees that the tx is built as it’s supposed to
1. Client sees the message on L1 via event logs
1. A TX is built and submitted by either the user or some relayer that meets the requirements of the ERC20GatewayDepositPredicate
1. A single call is made from the transaction script to the intended recipient Fuel token contract. This function verifies the sender and predicate owner of the InputMessage, parses the data from the InputMessage data field and mints the appropriate amount of tokens

![ERC20 Deposit Diagram](/docs/imgs/FuelMessagingDeposit.png)

## ERC20 Bridge Withdrawal

1. User starts a withdrawal by calling the FuelMyToken contract sending some coins to withdraw along with it
1. FuelMyToken contract looks to see what coins it was sent, burns them and then creates a MessageOutput via opcode
1. MessageOutput is noted on L1 by including the messagId in a merkle root in the state header committed to L1
1. After any necessary finalization period, the user calls to the FuelMessageInbox with a merkle proof of the previous sent message
1. The FuelMessageInbox verifies the given merkle proof and makes the message call to the L1ERC20Gateway specified in the message
1. The L1ERC20Gateway verifies it’s being called by the FuelMessageInbox and releases the specified amount of tokens to the specified address

![ERC20 Withdrawal Diagram](/docs/imgs/FuelMessagingDeposit.png)
