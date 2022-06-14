script;

use std::token::transfer_to_output;
use std::constants::NATIVE_ASSET_ID;
use std::address::Address;
use std::contract_id::ContractId;


fn main() -> () {
    let receiver = ~Address::from(NATIVE_ASSET_ID);
    let amount = 1000;
    transfer_to_output(amount, ~ContractId::from(NATIVE_ASSET_ID), receiver);
}
