script;

use std::address::Address;
use std::constants::BASE_ASSET_ID;
use std::contract_id::ContractId;
use std::identity::Identity;
use std::token::transfer;

fn main() -> () {
    // Let receiver be the base asset ID itself so we don't have to hard-code a random wallet address
    let receiver = Identity::Address(~Address::from(0x0101010101010101010101010101010101010101010101010101010101010101));
    let amount = 1000;
    transfer(amount, BASE_ASSET_ID, receiver);
}
