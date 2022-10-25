contract;

dep data;
dep errors;
dep events;
dep utils;

use bridge_fungible_token_abi::BridgeFungibleToken;
use contract_message_receiver::MessageReceiver;
use core::num::*;
use errors::BridgeFungibleTokenError;
use events::{RefundRegisteredEvent, WithdrawalEvent};
use std::{
    chain::auth::{
        AuthError,
        msg_sender,
    },
    constants::ZERO_B256,
    context::{
        call_frames::{
            contract_id,
            msg_asset_id,
        },
        msg_amount,
    },
    logging::log,
    storage::StorageMap,
    token::{
        burn,
        mint_to_address,
        transfer_to_address,
    },
    vm::evm::evm_address::EvmAddress,
};
use utils::{
    decompose,
    input_message_data,
    input_message_data_length,
    input_message_recipient,
    input_message_sender,
    parse_message_data,
    safe_b256_to_u64,
    send_message_output,
    transfer_tokens,
    u64_to_b256,
};

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////
storage {
    refund_amounts: StorageMap<(b256, b256), Option<b256>> = StorageMap {},
}

////////////////////////////////////////
// Storage-dependant private functions
////////////////////////////////////////
#[storage(write)]
fn register_refund(from: b256, asset: b256, amount: b256) {
    storage.refund_amounts.insert((from, asset), Option::Some(amount));
    log(RefundRegisteredEvent {
        from,
        asset,
        amount,
    });
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////
// Implement the process_message function required to be a message receiver
impl MessageReceiver for Contract {
    #[storage(read, write)]
    fn process_message(msg_idx: u8) {
        let input_sender = input_message_sender(1);

        require(input_sender.value == LAYER_1_ERC20_GATEWAY, BridgeFungibleTokenError::UnauthorizedSender);

        let message_data = parse_message_data(msg_idx);

        // @review this.
        // Register a refund if tokens don't match ?
        // register_refund(message_data.from, message_data.l1_asset, message_data.amount);
        require(message_data.l1_asset == LAYER_1_TOKEN, BridgeFungibleTokenError::IncorrectAssetDeposited);

        let amount = safe_b256_to_u64(message_data.amount);
        match amount {
            Result::Err(e) => {
                log(66);
                register_refund(message_data.from, message_data.l1_asset, message_data.amount);
            },
            Result::Ok(a) => {
                log(77);
                mint_to_address(amount, message_data.to);
                log(DepositEvent {
                    message_data.to,
                    message_data.from,
                    amount,
                });
            },
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    fn claim_refund(originator: b256, asset: b256) {
        let stored_amount = storage.refund_amounts.get((originator, asset));
        require(stored_amount.is_some(), BridgeFungibleTokenError::NoRefundAvailable);
        // reset the refund amount to 0
        storage.refund_amounts.insert((originator, asset), Option::None());

        let values = decompose(stored_amount.unwrap());
        // send a message to unlock this amount on the ethereum (L1) bridge contract
        send_message_output(originator, values.3);
    }

    #[storage(read)]
    fn withdraw_to(to: b256) {
        let withdrawal_amount = msg_amount();
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        let origin_contract_id = msg_asset_id();
        let sender = msg_sender().unwrap();

        // check that the correct asset was sent with call
        require(contract_id() == origin_contract_id, BridgeFungibleTokenError::IncorrectAssetDeposited);

        burn(withdrawal_amount);
        send_message_output(to, withdrawal_amount);
        log(WithdrawalEvent {
            to: to,
            from: sender,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
    }

    fn name() -> str[8] {
        NAME
    }

    fn symbol() -> str[5] {
        SYMBOL
    }

    fn decimals() -> u8 {
        DECIMALS
    }

    fn layer1_token() -> b256 {
        LAYER_1_TOKEN
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}
