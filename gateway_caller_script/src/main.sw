script;

use gateway_abi::Gateway;
use std::contract_id::ContractId;

fn main(gateway_id: ContractId) -> bool {

    // Note: predicate has already verified that gateway_id supplied as script data is the expected gateway_id
    let gateway_contract = abi(Gateway, gateway_id.into());
    let value = gateway_contract.processMessage();

    // TO DO: probably want to return whatever processMessage returns here
    true
}
