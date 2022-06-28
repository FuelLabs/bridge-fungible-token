script;

use token_abi::Token;
use std::contract_id::ContractId;
use std::tx::*;

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
/// Predicate has already checked that this input is an InputContract, so no need to check again
fn get_contract_input_contract_id(index: u8) -> ContractId {
    let ptr = tx_input_pointer(index);
    let contract_id_bytes = read_b256_from_pointer_offset(ptr, 128); // Contract ID starts at 17th word: 16 * 8 = 128
    ~ContractId::from(contract_id_bytes)
}

fn main() -> bool {
    // Get contract ID. Predicate has already checked this is an InputContract and that it corresponds to the contract ID specified in the Message data
    let input_contract_id = get_contract_input_contract_id(3);

    let token_contract = abi(Token, input_contract_id.into());
    let value = token_contract.finalizeDeposit();
    // TO DO: probably want to return whatever finalizeDeposit returns here...
    true
}
