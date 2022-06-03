predicate;

use std::address::Address;
use std::tx::*;
use std::assert::assert;
use std::hash::*;
use std::contract_id::ContractId;

/// Get the destination ContractId for coins to send for an output given a pointer to the output.
/// This method is only meaningful if the output type has the `to` field.
fn get_output_to(ptr: u32) -> ContractId {
    let address_bytes = asm(r1, r2: ptr) {
        lw r1 r2 i8;
        r1: b256
    };

    ~ContractId::from(address_bytes)
}

/// Get the ID of a contract input
fn get_input_contract_id(index: u8) -> ContractId {

    // Check that input at this index is a contract input
    assert(get_input_type(index) == 1u8);

    let ptr = tx_input_pointer(index);
    let contract_id_bytes = asm(r1, r2: ptr) {
        lw r1 r2 i200;
        r1: b256
    };
    ~ContractId::from(contract_id_bytes)
}

/// Get the type of an input at a given index
fn get_input_type(index: u8) -> u8 {
    let ptr = tx_input_pointer(index);
    let input_type = tx_input_type(ptr);
    input_type
}

/// Get the script spending the input behind this predicate. TO DO : replace with std-lib version when ready
fn get_script<T>() -> T {
    let script_ptr = std::context::registers::instrs_start();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

/// Get the script data of the script spending the input behind this predicate. TO DO : replace with std-lib version when ready
fn get_script_data<T>() -> T {
    let script_length = std::tx::tx_script_length();
    let script_length = script_length + script_length % 8;

    let is = std::context::registers::instrs_start();
    let script_data_ptr = is + script_length;
    let script_data = asm(r1: script_data_ptr) {
        r1: T
    };
    script_data
}

/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {
    /////////////////
    /// CONSTANTS ///
    /////////////////

    // The gateway contract ID
    const GATEWAY_CONTRACT_ID = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000);
    // The contract ID of the deposited token
    const TOKEN_CONTRACT_ID = ~ContractId::from(0x0000000000000000000000000000000000000000000000000000000000000000);
    // The minimum amount of gas sent with the transaction
    const MIN_GAS = 42;
    // The hash of the script which must spend the input belonging to this predicate
    const SPENDING_SCRIPT_HASH = 0x1010101010101010101010101010101010101010101010101010101010101010;

    //////////////////
    /// CONDITIONS ///
    //////////////////

    // Transaction must have exactly four inputs: a Coin input (for fees), a Message, the gateway Contract, and the token Contract (in that order)
    // TO DO: is there a more readable way to manage input/output types in Sway, rather than having to know the integer identifier of each type?
    let n_inputs = tx_inputs_count();
    assert(n_inputs == 4 && get_input_type(0) == 0u8 && get_input_type(1) == 2u8 && get_input_contract_id(2) == GATEWAY_CONTRACT_ID && get_input_contract_id(3) == TOKEN_CONTRACT_ID);

    // Verify a reasonable amount of gas. TO DO : define "reasonable"
    let gasLimit = tx_gas_limit();
    assert(gasLimit >= MIN_GAS);

    // Check the spending script is the authorized script. TO DO: Write script that must spend predicate so that len(script) and hash(script) can be hard-coded
    let script: [byte; 100] = get_script(); // replace 100 with actual script length
    let script_hash = sha256(script);
    assert(script_hash == SPENDING_SCRIPT_HASH);

    // Check the script data is the expected gateway contractId
    let script_data: b256 = get_script_data();
    let script_data_contract_id = ~ContractId::from(script_data);
    assert(script_data_contract_id == GATEWAY_CONTRACT_ID);

    // Check if output.to is the authorized receiver for the Coin output. Note: can't loop in a predicate. Assume it's first output for now:
    let ptr = tx_output_pointer(0);
    let address = get_output_to(ptr);
    assert(address == GATEWAY_CONTRACT_ID);

    // TO DO: Need to check there are no other coin outputs

    true
}
