library utils;

dep events;
dep data;

use events::{BurnEvent, MintEvent, TransferEvent};
use data::MessageData;
use std::{
    address::Address,
    constants::ZERO_B256,
    inputs::{
        Input,
        input_pointer,
        input_type,
    },
    logging::log,
    mem::read,
    token::{
        burn,
        mint,
        transfer_to_output,
    },
    vm::evm::evm_address::EvmAddress,
};

// TODO: [std-lib] remove once standard library functions have been added
const GTF_INPUT_MESSAGE_DATA_LENGTH = 0x11B;
const GTF_INPUT_MESSAGE_DATA = 0x11E;
const GTF_INPUT_MESSAGE_SENDER = 0x115;
const GTF_INPUT_MESSAGE_RECIPIENT = 0x116;

/// Get the length of a message input data
// TODO: [std-lib] replace with 'input_message_data_length'
pub fn input_message_data_length(index: u64) -> u64 {
    __gtf::<u64>(index, GTF_INPUT_MESSAGE_DATA_LENGTH)
}

/// Get the data of a message input
// TODO: [std-lib] replace with 'input_message_data'
pub fn input_message_data<T>(index: u64, offset: u64) -> T {
    read::<T>(__gtf::<u64>(index, GTF_INPUT_MESSAGE_DATA) + offset)
}

/// Get the sender of the input message at `index`.
// TODO: [std-lib] replace with 'input_message_sender'
pub fn input_message_sender(index: u64) -> Address {
    ~Address::from(__gtf::<b256>(index, GTF_INPUT_MESSAGE_SENDER))
}

/// Get the recipient of the input message at `index`.
// TODO: [std-lib] replace with 'input_message_recipient'
pub fn input_message_recipient(index: u64) -> Address {
    ~Address::from(__gtf::<b256>(index, GTF_INPUT_MESSAGE_RECIPIENT))
}

/// Get 4 64 bit words from a single b256 value.
pub fn decompose(val: b256) -> (u64, u64, u64, u64) {
    let w1 = get_word_from_b256(val, 0);
    let w2 = get_word_from_b256(val, 8);
    let w3 = get_word_from_b256(val, 16);
    let w4 = get_word_from_b256(val, 24);
    (w1, w2, w3, w4)
}

/// Extract a single 64 bit word from a b256 value using the specified offset.
fn get_word_from_b256(val: b256, offset: u64) -> u64 {
    let mut empty: u64 = 0;
    asm(r1: val, offset: offset, r2, res: empty) {
        add r2 r1 offset;
        lw res r2 i0;
        res: u64
    }
}

pub fn is_address(val: Identity) -> bool {
    match val {
        Identity::Address(a) => {
            true
        },
        Identity::ContractId => {
            false
        },
    }
}

pub fn correct_input_type(index: u64) -> bool {
    let type = input_type(1);
    match type {
        Input::Message => {
            true
        },
        _ => {
            false
        }
    }
}

pub fn parse_message_data(msg_idx: u8) -> MessageData {
    let mut msg_data = MessageData {
        fuel_token: ~ContractId::from(ZERO_B256),
        l1_asset: ~EvmAddress::from(ZERO_B256),
        from: ~Address::from(ZERO_B256),
        to: ~Address::from(ZERO_B256),
        amount: ZERO_B256,
    };

    // Parse the message data
    // @review can we trust that message.data is long enough/has all required data (does predicate enforce this) ?
    msg_data.fuel_token = ~ContractId::from(input_message_data::<b256>(msg_idx, 0));
    msg_data.l1_asset = ~EvmAddress::from(input_message_data::<b256>(msg_idx, 32));
    msg_data.from = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32));
    msg_data.to = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32 + 32));
    msg_data.amount = input_message_data::<b256>(msg_idx, 32 + 32 + 32 + 32);

    msg_data
}

// ref: https://github.com/FuelLabs/fuel-specs/blob/bd6ec935e3d1797a192f731dadced3f121744d54/specs/vm/instruction_set.md#smo-send-message-to-output
pub fn send_message(recipient: Address, coins: u64) {}

pub fn transfer_tokens(amount: u64, asset: ContractId, to: Address) {
    transfer_to_output(amount, asset, to);
}

#[storage(read)]
pub fn mint_tokens(amount: u64, from: Identity) -> bool {
    mint(amount);
    log(MintEvent {
        from: from,
        amount,
    });
    true
}

pub fn burn_tokens(amount: u64, from: Identity) {
    burn(amount);
    log(BurnEvent {
        from: from,
        amount,
    })
}
