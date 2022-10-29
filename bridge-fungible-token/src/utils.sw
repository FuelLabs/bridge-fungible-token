library utils;

dep errors;
dep events;
dep data;

use std::{
    constants::ZERO_B256,
    flags::{
        disable_panic_on_overflow,
        enable_panic_on_overflow,
    },
    math::*,
    u256::U256,
    vec::Vec,
};

use errors::BridgeFungibleTokenError;
use data::MessageData;

// the function selector for finalizeWithdrawal on the L1ERC20Gateway contract:
// finalizeWithdrawal(address,address,uint256)
const FINALIZE_WITHDRAWAL_SELECTOR: u64 = 0x53ef1461;

// TODO: [std-lib] remove once standard library functions have been added
const GTF_INPUT_MESSAGE_DATA_LENGTH = 0x11B;
const GTF_INPUT_MESSAGE_DATA = 0x11E;
const GTF_INPUT_MESSAGE_SENDER = 0x115;
const GTF_INPUT_MESSAGE_RECIPIENT = 0x116;

pub fn adjust_withdrawal_decimals(val: u64) -> b256 {
    let amount = ~U256::from(0, 0, 0, val);
    if DECIMALS < LAYER_1_DECIMALS {
        let factor = ~U256::from(0, 0, 0, 10.pow(LAYER_1_DECIMALS - DECIMALS));
       let components = amount.multiply(factor).into();
       compose(components)
    } else {
        // either decimals are the same, or decimals are negative.
        // decide how to handle negative decimals before mainnet
        compose((0, 0, 0, val))
    }
}

pub fn adjust_deposit_decimals(val: U256) -> Result<U256, BridgeFungibleTokenError> {
    if LAYER_1_DECIMALS > DECIMALS {
        let mut exponent = LAYER_1_DECIMALS - DECIMALS;
        let mut result = 1;
        while exponent > 0 {
            result = result * 10;
            exponent = exponent - 1;
        }
        let adjustment_factor = ~U256::from(0, 0, 0, result);

        if val.divide(adjustment_factor).multiply(adjustment_factor) == ~U256::min()
            && (val.gt(adjustment_factor)
            || val.eq(adjustment_factor))
        {
            Result::Ok(val.divide(adjustment_factor))
        } else {
            Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
        }
    } else {
        // either decimals are the same, or decimals are negative.
        // decide how to handle negative decimals before mainnet
        // @todo check that amount still fits in a u64 !
        Result::Ok(val)
    }
}

// Note: compose() & decompose() exist in sway-lib-core::ops but are not
// currently exported. If they are made `pub` we can reuse them here.
// Build a single b256 value from 4 64 bit words.
pub fn compose(words: (u64, u64, u64, u64)) -> b256 {
    let res: b256 = 0x0000000000000000000000000000000000000000000000000000000000000000;
    asm(w0: words.0, w1: words.1, w2: words.2, w3: words.3, result: res) {
        sw result w0 i0;
        sw result w1 i1;
        sw result w2 i2;
        sw result w3 i3;
        result: b256
    }
}

// Get 4 64-bit words from a single b256 value.
pub fn decompose(val: b256) -> (u64, u64, u64, u64) {
    let empty_tup = (0u64, 0u64, 0u64, 0u64);
    asm(r1: __addr_of(val), res1: empty_tup.0, res2: empty_tup.1, res3: empty_tup.2, res4: empty_tup.3, tup: empty_tup) {
        lw res1 r1 i0;
        lw res2 r1 i1;
        lw res3 r1 i2;
        lw res4 r1 i3;
        sw tup res1 i0;
        sw tup res2 i1;
        sw tup res3 i2;
        sw tup res4 i3;
        tup: (u64, u64, u64, u64)
    }
}

pub fn parse_message_data(msg_idx: u8) -> MessageData {
    let mut msg_data = MessageData {
        fuel_token: ~ContractId::from(ZERO_B256),
        l1_asset: ZERO_B256,
        from: ZERO_B256,
        to: ~Address::from(ZERO_B256),
        amount: ZERO_B256,
    };

    // Parse the message data
    msg_data.fuel_token = ~ContractId::from(input_message_data::<b256>(msg_idx, 0));
    msg_data.l1_asset = input_message_data::<b256>(msg_idx, 32);
    msg_data.from = input_message_data::<b256>(msg_idx, 32 + 32);
    msg_data.to = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32 + 32));
    msg_data.amount = input_message_data::<b256>(msg_idx, 32 + 32 + 32 + 32);

    msg_data
}

pub fn encode_data(to: b256, amount: b256) -> Vec<u64> {
    let mut data = ~Vec::with_capacity(13);
    // start with the function selector
    data.push(FINALIZE_WITHDRAWAL_SELECTOR);

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

    // add the amount of tokens
    let (amount_1, amount_2, amount_3, amount_4) = decompose(amount);
    data.push(amount_1);
    data.push(amount_2);
    data.push(amount_3);
    data.push(amount_4);

    data
}

/// Get the length of a message input data
// TODO: [std-lib] replace with 'input_message_data_length'
pub fn input_message_data_length(index: u64) -> u64 {
    __gtf::<u64>(index, GTF_INPUT_MESSAGE_DATA_LENGTH)
}

/// Get the data of a message input
// TODO: [std-lib] replace with 'input_message_data'
pub fn input_message_data<T>(index: u64, offset: u64) -> T {
    let data = __gtf::<raw_ptr>(index, GTF_INPUT_MESSAGE_DATA);
    let data_with_offset = data + offset;
    data_with_offset.read::<T>()
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
