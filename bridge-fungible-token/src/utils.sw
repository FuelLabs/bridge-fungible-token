library utils;

dep errors;
dep events;
dep data;

use std::{
    alloc::alloc,
    mem::copy,
    outputs::{
        Output,
        output_count,
        output_type,
    },
    revert::revert,
    vec::Vec,
};

use errors::BridgeFungibleTokenError;
use events::{BurnEvent, MintEvent, TransferEvent};
use data::MessageData;
use std::{
    constants::ZERO_B256,
    inputs::{
        Input,
        input_pointer,
        input_type,
    },
    logging::log,
    mem::{
        addr_of,
        read,
        write,
    },
    token::{
        burn,
        mint_to_address,
        transfer_to_address,
    },
    vm::evm::evm_address::EvmAddress,
};

// TODO: [std-lib] remove once standard library functions have been added
const GTF_INPUT_MESSAGE_DATA_LENGTH = 0x11B;
const GTF_INPUT_MESSAGE_DATA = 0x11E;
const GTF_INPUT_MESSAGE_SENDER = 0x115;
const GTF_INPUT_MESSAGE_RECIPIENT = 0x116;

pub fn mint_and_transfer_tokens(amount: u64, to: Address) {
    mint_to_address(amount, to);
    log(MintEvent { amount, to });
}

pub fn burn_tokens(amount: u64, from: Identity) {
    burn(amount);
    log(BurnEvent {
        from: from,
        amount,
    })
}

pub fn correct_input_type(index: u64) -> bool {
    let type = input_type(index);
    match type {
        Input::Message => {
            true
        },
        _ => {
            false
        }
    }
}

pub fn safe_b256_to_u64(val: b256) -> Result<u64, BridgeFungibleTokenError> {
    // first, decompose into u64 values
    let u64s = decompose(val);
    log(u64s.3);

    // verify amount will require no partial refund of dust by ensuring that
    // the first 9 decimal places in the passed-in value are empty,
    // then verify amount is not too small or too large
    if (u64s.3 / 1_000_000_000) * 1_000_000_000 == u64s.3
        && u64s.3 >= 1_000_000_000
        && u64s.0 == 0
        && u64s.1 == 0
        && u64s.2 == 0
    {
        // reduce decimals by 9 places
        Result::Ok(u64s.3 / 1_000_000_000)
    } else {
        Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
    }
}

/// Build a single b256 value from a u64 left-padded with 3 0u64's
pub fn u64_to_b256(val: u64) -> b256 {
    let res: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    let ptr = addr_of(res);
    write(ptr, 0);
    write(ptr + 8, 0);
    write(ptr + 16, 0);
    write(ptr + 24, val);
    res
}

/// Get 4 64 bit words from a single b256 value.
pub fn decompose(val: b256) -> (u64, u64, u64, u64) {
    let w1 = single_word_from_b256(val, 0);
    let w2 = single_word_from_b256(val, 8);
    let w3 = single_word_from_b256(val, 16);
    let w4 = single_word_from_b256(val, 24);
    (w1, w2, w3, w4)
}

/// Extract a single 64 bit word from a b256 value using the specified offset.
fn single_word_from_b256(val: b256, offset: u64) -> u64 {
    let mut empty: u64 = 0;
    asm(r1: val, offset: offset, r2, res: empty) {
        add r2 r1 offset;
        lw res r2 i0;
        res: u64
    }
}

pub fn parse_message_data(msg_idx: u8) -> MessageData {
    let mut msg_data = MessageData {
        fuel_token: ~ContractId::from(ZERO_B256),
        l1_asset: ~EvmAddress::from(ZERO_B256),
        from: ~EvmAddress::from(ZERO_B256),
        to: ~Address::from(ZERO_B256),
        amount: ZERO_B256,
    };

    // Parse the message data
    msg_data.fuel_token = ~ContractId::from(input_message_data::<b256>(msg_idx, 0));
    msg_data.l1_asset = ~EvmAddress::from(input_message_data::<b256>(msg_idx, 32));
    msg_data.from = ~EvmAddress::from(input_message_data::<b256>(msg_idx, 32 + 32));
    msg_data.to = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32 + 32));
    msg_data.amount = input_message_data::<b256>(msg_idx, 32 + 32 + 32 + 32);

    msg_data
}
pub fn encode_data(to: b256, amount: u64) -> Vec<u64> {
    let mut data = ~Vec::with_capacity(13);
    // start with the function selector for finalizeWithdrawal on the L1ERC20Gateway contract
    data.push(0x53ef1461);

    // add the address to recieve coins
    let (recip_1, recip_2, recip_3, recip_4) = decompose(to);
    data.push(recip_1);
    data.push(recip_2);
    data.push(recip_3);
    data.push(recip_4);

    // add the address of the L1 token contract
    let (token_1, token_2, token_3, token_4) = decompose(LAYER_1_TOKEN);
    data.push(token_1);
    data.push(token_2);
    data.push(token_3);
    data.push(token_4);

    // add the amount of tokens, padding with 3 0u64s to allow reading as a b256 on the other side of the bridge.
    data.push(0u64);
    data.push(0u64);
    data.push(0u64);
    data.push(amount);

    data
}

pub fn send_message_output(to: b256, amount: u64, ) {
    send_message(LAYER_1_ERC20_GATEWAY, encode_data(to, amount), 0);
}

pub fn transfer_tokens(amount: u64, asset: ContractId, to: Address) {
    transfer_to_address(amount, asset, to);
}

///////////////////////////////////////
// TODO: Replace with stdlib functions
///////////////////////////////////////
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

/// Sends a message to `recipient` of length `msg_len` through `output` with amount of `coins`
///
/// # Arguments
///
/// * `recipient` - The address of the message recipient
/// * `msg_data` - arbitrary length message data
/// * `coins` - Amount of base asset sent
pub fn send_message(recipient: b256, msg_data: Vec<u64>, coins: u64) {
    let mut recipient_heap_buffer = 0;
    let mut data_heap_buffer = 0;
    let mut size = 0;

    // If msg_data is empty, we just ignore it and pass `smo` a pointer to the inner value of recipient.
    // Otherwise, we allocate adjacent space on the heap for the data and the recipient and copy the
    // data and recipient values there
    if msg_data.is_empty() {
        recipient_heap_buffer = addr_of(recipient);
    } else {
        size = msg_data.len() * 8;
        data_heap_buffer = alloc(size);
        recipient_heap_buffer = alloc(32);
        copy(msg_data.buf.ptr, data_heap_buffer, size);
        copy(addr_of(recipient), recipient_heap_buffer, 32);
    };

    let mut index = 0;
    let outputs = output_count();

    while index < outputs {
        let type_of_output = output_type(index);
        if let Output::Message = type_of_output {
            asm(r1: recipient_heap_buffer, r2: size, r3: index, r4: coins) {
                smo r1 r2 r3 r4;
            };
            return;
        }
        index += 1;
    }
    revert(FAILED_SEND_MESSAGE_SIGNAL);
}

const FAILED_SEND_MESSAGE_SIGNAL = 0xffff_ffff_ffff_0002;
