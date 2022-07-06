script;

use std::address::Address;
use std::constants::BASE_ASSET_ID;
use std::contract_id::ContractId;
use std::identity::Identity;
use std::token::transfer;

fn main() -> () {
    // The predicate constrains the transaction to be precisely this script
    let receiver = Identity::Address(~Address::from(0x0101010101010101010101010101010101010101010101010101010101010101));
    let amount = 1000;
    transfer(amount, BASE_ASSET_ID, receiver);
}
