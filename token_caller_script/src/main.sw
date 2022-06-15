script;

use token_abi::Token;
use std::contract_id::ContractId;

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

fn main() -> bool {

    // Get contract ID. Predicate has already checked this corresponds to the contract ID specified in the Message data
    let input_contract_id = get_input_contract_id(3);

    let token_contract = abi(Token, input_contract_id.into());
    let value = token_contract.processMessage();
    // TO DO: probably want to return whatever processMessage returns here
    true
}
