library utils;

dep errors;
dep events;
dep data;

use std::{
    constants::ZERO_B256,
    flags::{
        disable_panic_on_overflow,
        enable_panic_on_overflow
    },
    math::*,
    vec::Vec
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

fn decimal_adjustment_factor() -> u64 {
    if LAYER_1_DECIMALS > DECIMALS {
        10.pow(LAYER_1_DECIMALS - DECIMALS)
    } else if LAYER_1_DECIMALS < DECIMALS {
        // TODO: Discuss how we want to handle this case
        1
    } else {
        1
    }
}

// used to increase the amount of "decimal" places by appending the
// appropriate amount of 0s to the u64 via multiplication by the appropriate
// adjustment_factor.
// Potential overflow is accounted for & the result is returned as a b256
pub fn safe_u64_to_b256(val: u64) -> b256 {
    let adjustment_factor = decimal_adjustment_factor();
    let mut result: b256 = ZERO_B256;
    disable_panic_on_overflow();
    asm(product, overflow, value: val, factor: adjustment_factor, ptr: __addr_of(result)) {
        mul product value factor;
        move overflow of;
        sw ptr product i3;
        sw ptr overflow i2;
    }
    enable_panic_on_overflow();
    result
}

pub fn safe_b256_to_u64(val: b256) -> Result<u64, BridgeFungibleTokenError> {
    // first, decompose into u64 values
    let u64s = decompose(val);
    let adjustment_factor = decimal_adjustment_factor();

    // verify amount will require no partial refund of dust by ensuring that
    // the first n decimal places in the passed-in value are empty,
    // then verify amount is not too small or too large
    // @review this, make no assumptions about relative size of decimals from different layers
    // @todo use modulo instead of div & then mul !
    // @todo use
    if (u64s.3 / adjustment_factor) * adjustment_factor == u64s.3
        && u64s.3 >= adjustment_factor
        && u64s.0 == 0
        && u64s.1 == 0
        && u64s.2 == 0
    {
        // reduce decimals
        Result::Ok(u64s.3 / adjustment_factor)
    } else {
        Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
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
