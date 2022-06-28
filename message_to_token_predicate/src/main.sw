predicate;

use std::address::Address;
use std::tx::*;
use std::assert::assert;
use std::hash::*;
use std::contract_id::ContractId;

// TO DO: Is there a better way to do this ?
const INPUT_COIN = 0u8;
const INPUT_CONTRACT = 1u8;
const INPUT_MESSAGE = 2u8;
const OUTPUT_CONTRACT = 1u8;
const OUTPUT_CHANGE = 3u8;
const OUTPUT_VARIABLE = 4u8;

// TO DO : factor out these functions to a library (or add to std::tx)

// Read 256 bits from memory at an offset from a given pointer
fn read_b256_from_pointer_offset(pointer: u32, offset: u32) -> b256 {
    asm(buffer, ptr: pointer, off: offset) {
        // Need to skip over `off` bytes
        add ptr ptr off;
        // Save old stack pointer
        move buffer sp;
        // Extend stack by 32 bytes
        cfei i32;
        // Copy 32 bytes
        mcpi buffer ptr i32;
        // `buffer` now points to the 32 bytes
        buffer: b256
    }
}

/// Get the ID of a contract input
fn verify_and_get_contract_input_contract_id(index: u8) -> ContractId {
    // Check that input at this index is a contract input
    assert(get_input_type(index) == INPUT_CONTRACT);
    let ptr = tx_input_pointer(index);
    let contract_id_bytes = read_b256_from_pointer_offset(ptr, 128); // Contract ID starts at 17th word: 16 * 8 = 128
    ~ContractId::from(contract_id_bytes)
}

// Get the contract ID from a message input's data
fn verify_and_get_message_input_data_contract_id(index: u8) -> ContractId {
    // Check that input at this index is a message input
    assert(get_input_type(index) == INPUT_MESSAGE);

    let ptr = tx_input_pointer(index);
    let contract_id_bytes = read_b256_from_pointer_offset(ptr, 192); // Contract ID is at start of data, which is at 24th word: 24 * 8 = 192
    ~ContractId::from(contract_id_bytes)
}

/// Get the type of an input at a given index
fn get_input_type(index: u8) -> u8 {
    let ptr = tx_input_pointer(index);
    let input_type = tx_input_type(ptr);
    input_type
}

/// Get the type of an output at a given index
fn get_output_type(index: u8) -> u8 {
    let ptr = tx_output_pointer(index);
    let output_type = tx_output_type(ptr);
    output_type
}

/// Get the script spending the input belonging to this predicate hash.
fn get_script_bytecode<T>() -> T {
    let script_ptr = tx_script_start_offset();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {
    /////////////////
    /// CONSTANTS ///
    /////////////////

    // The minimum gas limit for the transaction not to revert out-of-gas.
    const MIN_GAS = 42;
    // The hash of the script which must spend the input belonging to this predicate
    const SPENDING_SCRIPT_HASH = 0xf127314d1d30bb8398c2fcde2a1d799a61d3dc5875a56a0e047807e51fd6f9ea;

    //////////////////
    /// CONDITIONS ///
    //////////////////

    // Verify script bytecode hash is expected
    let script: [u64;
    36] = get_script_bytecode(); // Note : Make sure length is script bytecode length rounded up to next word
    let script_hash = sha256(script);
    assert(script_hash == SPENDING_SCRIPT_HASH);

    // Verify gas limit is high enough
    let gasLimit = tx_gas_limit();
    assert(gasLimit >= MIN_GAS);

    // Transaction must have exactly three inputs: a Coin input (for fees), a Message, and the token Contract (in that order)
    assert(tx_inputs_count() == 3);
    assert(get_input_type(0) == INPUT_COIN);
    let message_data_contract_id = verify_and_get_message_input_data_contract_id(2);
    let input_contract_id = verify_and_get_contract_input_contract_id(3);

    // Check contract ID from the contract input matches the one specified in the message data
    assert(input_contract_id == message_data_contract_id);

    // Transation must have exactly 3 outputs: OutputVariable, OutputContract, and OutputChange (in that order)
    let n_outputs = tx_outputs_count();
    assert(n_outputs == 3 && get_output_type(0) == OUTPUT_VARIABLE && get_output_type(1) == OUTPUT_CONTRACT && get_output_type(2) == OUTPUT_CHANGE); // Single output is OutputVariable

    true
}
