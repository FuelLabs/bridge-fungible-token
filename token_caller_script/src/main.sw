script;

use token_abi::Token;
use std::contract_id::ContractId;

fn main() -> bool {
    let token_contract_id = ~ContractId::from(0x1010101010101010101010101010101010101010101010101010101010101010);
    let token_contract = abi(Token, token_contract_id.into());
    let value = token_contract.processMessage();
    // TO DO: probably want to return whatever processMessage returns here
    true
}
