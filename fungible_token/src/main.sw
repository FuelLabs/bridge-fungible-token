contract;

use std::{
    address::Address, 
    assert::require,
    chain::auth::{AuthError, Sender, msg_sender},
    result::*,
    vm::evm::evm_address::EvmAddress
};

abi FungibleToken {
    fn constructor(owner: Sender) -> bool;
    fn mint(to: Sender, amount: u64) -> bool;
    fn burn(from: Sender, amount: u64) -> bool;
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}

enum Error {
    CannotReinitialize: (),
    StateNotInitialized: (),
    UnauthorizedUser: (),
}

storage {
    owner: b256,
    state: u64,
}

impl FungibleToken for Contract {

    fn constructor(owner: Sender) -> bool {
        require(storage.state == 0, Error::CannotReinitialize);
        storage.owner = _get_address(owner);
        storage.state = 1;
        true
    }

    fn mint(to: Sender, amount: u64) -> bool {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        let address = _get_address(sender.unwrap());

        require(storage.owner == address, Error::UnauthorizedUser);

        true
    }

    fn burn(from: Sender, amount: u64) -> bool {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        let address = _get_address(sender.unwrap());

        require(storage.owner == address, Error::UnauthorizedUser);

        true
    }

    fn name() -> str[11] {
        "placeholder"
    }

    fn symbol() -> str[11] {
        "placeholder"
    }

    fn decimals() -> u8 {
        2
    }

    fn layer1_token() -> EvmAddress {
        ~EvmAddress::from(0x0000000000000000000000000000000000000000000000000000000000000000)
    }

    fn layer1_decimals() -> u8 {
        2
    }
}

fn _get_address(user: Sender) -> b256 {
    match user {
        Sender::Address(address) => address.value, Sender::ContractId(address) => address.value, 
    }
}
