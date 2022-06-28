script;

use std::token::transfer_to_output;
use std::constants::BASE_ASSET_ID;
use std::address::Address;
use std::contract_id::ContractId;

fn main() -> () {
    // Let receiver be the base asset ID itself so we don't have to hard-code a random wallet address
    let receiver = ~Address::from(BASE_ASSET_ID);
    let amount = 1000;
    transfer_to_output(amount, ~ContractId::from(BASE_ASSET_ID), receiver);
}
