contract;

use std::{storage::StorageMap, identity::Identity, vm::evm::evm_address::EvmAddress, context::{registers::balance, call_frames::msg_asset_id}};

enum L2GatewayError {
    NoCoinsForwarded: (),
}


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
        // Verify an amount of coins was sent with this transaction
        let withdrawal_amount = balance();
        require(withdrawal_amount != 0, L2GatewayError::NoCoinsForwarded);
        // Find what contract the coins originate from
        let origin_contract_id = msg_asset_id();
        // Verify this gateway can call to burn these coins
        // ???
        let token_contract = abi(FungibleToken, origin_contract_id);
        // Burn the coins sent (call `burn()` on L2 token contract)
        token_contract.burn(withdrawal_amount)
        // Output a message to release tokens locked on L1
        // ???
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
