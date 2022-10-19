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
    address::Address,
    assert::assert,
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
    contract_id::ContractId,
    identity::Identity,
    logging::log,
    option::Option,
    result::Result,
    revert::{
        require,
        revert,
    },
    storage::StorageMap,
    u256::U256,
    vec::Vec,
    vm::evm::evm_address::EvmAddress,
};
use utils::{
    b256_to_u64_words,
    burn_tokens,
    correct_input_type,
    input_message_data,
    input_message_data_length,
    input_message_recipient,
    input_message_sender,
    mint_tokens,
    parse_message_data,
    send_message,
    transfer_tokens,
};

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////
storage {
    refund_amounts: StorageMap<(EvmAddress, EvmAddress), U256> = StorageMap {},
}

////////////////////////////////////////
// Storage-dependant private functions
////////////////////////////////////////
#[storage(write)]
pub fn register_refund(from: EvmAddress, asset: EvmAddress, amount: U256) {
    storage.refund_amounts.insert((from, asset), amount);
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

        require(input_sender.value == LAYER_1_ERC20_GATEWAY, BridgeFungibleTokenError::UnauthorizedUser);

        let message_data = parse_message_data(msg_idx);

        require(message_data.l1_asset == ~EvmAddress::from(LAYER_1_TOKEN), BridgeFungibleTokenError::IncorrectAssetDeposited);

        if message_data.l1_asset != ~EvmAddress::from(LAYER_1_TOKEN)
        {
            // Register a refund if tokens don't match
            register_refund(message_data.from, message_data.l1_asset, message_data.amount);
        } else {
            let mut b256_amount = message_data.amount;
            let u64_words = b256_to_u64_words(b256_amount);
            let amount = ~U256::from(u64_words.0, u64_words.1, u64_words.2, u64_words.3).as_u64();
            match amount {
                Result::Err(e) => {
                    register_refund(message_data.from, message_data.l1_asset, amount);
                },
                Result::Ok(amount) => {
                    mint_tokens(amount, message_data.to);
                    transfer_tokens(amount, contract_id(), message_data.to);
                },
            }
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    fn claim_refund(originator: EvmAddress, asset: EvmAddress) {
        let stored_amount = storage.refund_amounts.get((originator, asset, ));
        // reset the refund amount to 0
        storage.refund_amounts.insert((originator, asset), ~U256::new());
        // send a message to unlock this amount on the ethereum (L1) bridge contract contract
        let mut data: Vec<u64> = ~Vec::new();
        data.push(11);
        data.push(33);
        data.push(55);
        send_message(originator, data, stored_amount, LAYER_1_TOKEN);
    }

    #[storage(read)]
    fn withdraw_to(to: EvmAddress) {
        let withdrawal_amount = msg_amount();
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        let origin_contract_id = msg_asset_id();
        let sender = msg_sender().unwrap();

        // check that the correct asset was sent with call
        require(contract_id() == origin_contract_id, BridgeFungibleTokenError::IncorrectAssetDeposited);

        burn_tokens(withdrawal_amount, sender);
        send_message(to, withdrawal_amount);
        log(WithdrawalEvent {
            to: to,
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

    fn layer1_token() -> EvmAddress {
        ~EvmAddress::from(LAYER_1_TOKEN)
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}
