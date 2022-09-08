contract;

dep utils;
dep errors;
dep events;

use bridge_fungible_token_abi::BridgeFungibleToken;
use contract_message_receiver::MessageReceiver;
use core::num::*;
use errors::BridgeFungibleTokenError;
use events::{BurnEvent, MintEvent, TransferEvent, WithdrawalEvent};
use std::{
    address::Address,
    assert::{assert, require},
    chain::auth::{AuthError, msg_sender},
    constants::ZERO_B256,
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    identity::Identity,
    logging::log,
    option::Option,
    result::Result,
    revert::revert,
    storage::StorageMap,
    token::{burn, mint, transfer_to_output},
    tx::{tx_input_pointer, tx_input_type, INPUT_MESSAGE},
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};
use utils::{input_message_data, input_message_data_length};

////////////////////////////////////////
// Constants
////////////////////////////////////////

// @todo update with actual predicate root
const PREDICATE_ROOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 9u8;
// @todo update with actual L1 token address
const LAYER_1_TOKEN = ~EvmAddress::from(0x0000000000000000000000000000000000000000000000000000000000000000);
const LAYER_1_DECIMALS = 18u8;

////////////////////////////////////////
// Data
////////////////////////////////////////

struct MessageData {
    asset: b256,
    fuel_token: ContractId,
    to: Identity,
    amount: u64,
}

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    // @review what is needed !
    counter: u64 = 0,
    data1: ContractId = ~ContractId::from(ZERO_B256),
    data2: u64 = 0,
    data3: b256 = ZERO_B256,
    data4: Address = ~Address::from(ZERO_B256),
    ///
    initialized: bool,
    owner: Identity,
    refund_amounts: StorageMap<(b256, b256), U256>,
}

// Implement the process_message function required to be a message receiver
impl MessageReceiver for Contract {
    /**
    // @review old impl...
    fn parse_message_data(input_ptr: u32) -> MessageData {
        // @todo replace placeholder with stdlib getter using `gtf`
        let raw_data = GTF_INPUT_MESSAGE_DATA;

        // @todo replace dummy data with the real values
        MessageData {
            asset: 0x0000000000000000000000000000000000000000000000000000000000000000,
            fuel_token: contract_id(),
            to: Identity::Address(~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000)),
            amount: 42
        }
    }
    */
    #[storage(read, write)]
    fn process_message(msg_idx: u8) {

        storage.counter = storage.counter + 1;

        // Parse the message data
        let data_length = input_message_data_length(msg_idx);
        if (data_length >= 32) {
            let contract_id: b256 = input_message_data(msg_idx, 0);
            storage.data1 = ~ContractId::from(contract_id);
        }
        if (data_length >= 32 + 8) {
            let num: u64 = input_message_data(msg_idx, 32);
            storage.data2 = num;
        }
        if (data_length >= 32 + 8 + 32) {
            let big_num: b256 = input_message_data(msg_idx, 32 + 8);
            storage.data3 = big_num;
        }
        if (data_length >= 32 + 8 + 32 + 32) {
            let address: b256 = input_message_data(msg_idx, 32 + 8 + 32);
            storage.data4 = ~Address::from(address);
        }
    }
}

impl BridgeFungibleToken for Contract {

}
