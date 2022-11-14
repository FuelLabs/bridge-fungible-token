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
const FINALIZE_WITHDRAWAL_SELECTOR: u64 = 0x53ef146100000000;

// TODO: [std-lib] remove once standard library functions have been added
const GTF_INPUT_MESSAGE_DATA_LENGTH = 0x11B;
const GTF_INPUT_MESSAGE_DATA = 0x11E;
const GTF_INPUT_MESSAGE_SENDER = 0x115;
const GTF_INPUT_MESSAGE_RECIPIENT = 0x116;

fn bn_mul(bn: U256, d: u64) -> (b256, u64) {
    disable_panic_on_overflow();
    let tuple_result: (b256, u64) = (
        0x0000000000000000000000000000000000000000000000000000000000000000,
        0,
    );
    let product_buffer = asm(bn: __addr_of(bn), d: d, c0, c1, v, f, product, carry_offset, product_buffer: __addr_of(tuple_result)) {
        // Run multiplication on the lower 64bit word
        lw v bn i3; // load the word in (bn + 3 words) into v
        mul v v d; // multiply v * d and save result in v
        move c1 of; // record the carry
        sw product_buffer v i3; // store the word in v in product_buffer + 3 words
        // Run multiplication on the next 64bit word
        lw v bn i2;
        mul v v d;
        move c0 of;
        add v v c1; // add the previous carry
        add c1 c0 of; // record the total new carry
        sw product_buffer v i2;

        // Run multiplication on the next 64bit word
        lw v bn i1;
        mul v v d;
        move c0 of;
        add v v c1; // add the previous carry
        add c1 c0 of; // record the total new carry
        sw product_buffer v i1;

        // Run multiplication on the next 64bit word
        lw v bn i0;
        mul v v d;
        move c0 of;
        add v v c1; // add the previous carry
        add c1 c0 of; // record the total new carry
        move c0 of;
        sw product_buffer v i0;

        // add address of product and 4 words/32 bytes, store in carry_offset
        addi carry_offset product_buffer i32;
        sw carry_offset c1 i0;

        product_buffer: (b256, u64)
    };

    enable_panic_on_overflow();
    product_buffer
}

/// Make any necessary adjustments to decimals(precision) on the amount
/// to be withdrawn. This amount needs to be passed via message.data as a b256
pub fn adjust_withdrawal_decimals(val: u64) -> b256 {
    if DECIMALS < LAYER_1_DECIMALS {
        let amount = U256::from((0, 0, 0, val));
        let (product, overflow) = bn_mul(amount, 10.pow(LAYER_1_DECIMALS - DECIMALS));
        product
    } else {
        // Either decimals are the same, or decimals are negative.
        // TODO: Decide how to handle negative decimals before mainnet.
        // For now we make no decimal adjustment for either case.
        compose((0, 0, 0, val))
    }
}

/// Make any necessary adjustments to decimals(precision) on the deposited value, and return either a converted u64 or an error if the conversion can't be achieved without overflow or loss of precision.
pub fn adjust_deposit_decimals(msg_val: b256) -> Result<u64, BridgeFungibleTokenError> {
    let value = U256::from(decompose(msg_val));

    if LAYER_1_DECIMALS > DECIMALS {
        let decimal_diff = LAYER_1_DECIMALS - DECIMALS;
        //10.pow(19) fits in a u64, but 10.pow(20) would overflow when
        // calculating adjustment_factor below.
        // There's no need to check this in adjust_withdrawal_decimals();
        // if an overflow is going to occur when calculating adjustment_factor,
        // it will be caught here first.
        if decimal_diff > 19u8 {
            return Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
        };
        let adjustment_factor = 10.pow(LAYER_1_DECIMALS - DECIMALS);
        let bn_factor = U256::from((0, 0, 0, adjustment_factor));
        let adjusted = value.divide(bn_factor);
        let (product, overflow) = bn_mul(adjusted, 10.pow(LAYER_1_DECIMALS - DECIMALS));

        let decomposed = decompose(product);
        let temp_val = U256::from(decomposed);

        if temp_val == value
            && (value.gt(bn_factor)
            || value.eq(bn_factor))
        {
            let val_result = adjusted.as_u64();
            match val_result {
                Result::Err(e) => {
                    Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
                },
                Result::Ok(val) => {
                    Result::Ok(val)
                },
            }
        } else {
            Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
        }
    } else {
        // Either decimals are the same, or decimals are negative.
        // TODO: Decide how to handle negative decimals before mainnet.
        // For now we make no decimal adjustment for either case.
        let val_result = value.as_u64();
        match val_result {
            Result::Err(e) => {
                Result::Err(BridgeFungibleTokenError::BridgedValueIncompatability)
            },
            Result::Ok(val) => {
                Result::Ok(val)
            },
        }
    }
}

/// Build a single b256 value from a tuple of 4 u64 values.
pub fn compose(words: (u64, u64, u64, u64)) -> b256 {
    asm(r1: __addr_of(words)) { r1: b256 }
}

/// Get a tuple of 4 u64 values from a single b256 value.
pub fn decompose(val: b256) -> (u64, u64, u64, u64) {
    asm(r1: __addr_of(val)) { r1: (u64, u64, u64, u64) }
}

/// Read the bytes passed as message data into an in-memory representation using the MessageData type.
pub fn parse_message_data(msg_idx: u8) -> MessageData {
    let mut msg_data = MessageData {
        fuel_token: ContractId::from(ZERO_B256),
        l1_asset: ZERO_B256,
        from: ZERO_B256,
        to: Address::from(ZERO_B256),
        amount: ZERO_B256,
    };

    // Parse the message data
    msg_data.fuel_token = ContractId::from(input_message_data::<b256>(msg_idx, 0));
    msg_data.l1_asset = input_message_data::<b256>(msg_idx, 8);
    msg_data.from = input_message_data::<b256>(msg_idx, 8 + 8);
    msg_data.to = Address::from(input_message_data::<b256>(msg_idx, 8 + 8 + 8));
    msg_data.amount = input_message_data::<b256>(msg_idx, 8 + 8 + 8 + 8);
    msg_data
}

/// Encode the data to be passed out of the contract when sending a message
pub fn encode_data(to: b256, amount: b256) -> Vec<u64> {
    let mut data = Vec::with_capacity(13);
    let (recip_1, recip_2, recip_3, recip_4) = decompose(to);
    let (token_1, token_2, token_3, token_4) = decompose(LAYER_1_TOKEN);
    let (amount_1, amount_2, amount_3, amount_4) = decompose(amount);

    // start with the function selector
    data.push(FINALIZE_WITHDRAWAL_SELECTOR + (recip_1 >> 32));

    // add the address to recieve coins
    data.push((recip_1 << 32) + (recip_2 >> 32));
    data.push((recip_2 << 32) + (recip_3 >> 32));
    data.push((recip_3 << 32) + (recip_4 >> 32));
    data.push((recip_4 << 32) + (token_1 >> 32));

    // add the address of the L1 token contract
    data.push((token_1 << 32) + (token_2 >> 32));
    data.push((token_2 << 32) + (token_3 >> 32));
    data.push((token_3 << 32) + (token_4 >> 32));
    data.push((token_4 << 32) + (amount_1 >> 32));

    // add the amount of tokens
    data.push((amount_1 << 32) + (amount_2 >> 32));
    data.push((amount_2 << 32) + (amount_3 >> 32));
    data.push((amount_3 << 32) + (amount_4 >> 32));
    data.push(amount_4 << 32);
    data
}

/// Get the data of a message input
// TODO: [std-lib] replace with 'input_message_data'
pub fn input_message_data<T>(index: u64, offset: u64) -> T {
    let data = __gtf::<raw_ptr>(index, GTF_INPUT_MESSAGE_DATA);
    let data_with_offset = data.add(offset / 8);
    data_with_offset.read::<T>()
}

/// Get the sender of the input message at `index`.
// TODO: [std-lib] replace with 'input_message_sender'
pub fn input_message_sender(index: u64) -> Address {
    Address::from(__gtf::<b256>(index, GTF_INPUT_MESSAGE_SENDER))
}
