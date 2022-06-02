contract;

use std::{storage::StorageMap, identity::Identity, vm::evm::evm_address::EvmAddress};


storage {
    refund_amounts: StorageMap<(b256, b256), u64>,
}

abi L2Gateway {
    fn withdraw_to(to: Identity);
    fn process_message();
    fn withdraw_refund(originator: Identity, l1_token: EvmAddress);
}

impl L2Gateway for Contract {
    fn withdraw_to(to: Identity) {
        // start withdrawal
        // Verify an amount of cou=ins was sent with this transaction
        // Find what contract the coins originat from
        // Verify this gateway can call to burn these coins
        // Burn the coins sent (call `burn()` on L2 token contract)
        // Output a message to release tokens locked on L1
    }

    fn process_message() {
        // Finalize deposit
        // Verify first message input owner predicate == MessageToGatewayPredicate
        // Verify the msg sender is the L1ERC20Gateway contract
        // *predicate will have already verified only 1 message input
        // *predicate will have already verified this contract is supposed to receive mesage
        // * no value will be sent by the L1ERC20Gateway contract
    }

    fn withdraw_refund(originator: Identity, l1_token: EvmAddress) {}
}
