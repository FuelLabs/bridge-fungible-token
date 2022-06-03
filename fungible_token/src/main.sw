contract;

dep abi;
dep errors;
dep events;

use std::{
    address::Address, 
    assert::require,
    chain::auth::{AuthError, Sender, msg_sender},
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    logging::log,
    result::*,
    revert::revert,
    token::{mint_to_address, mint_to_contract, burn},
    vm::evm::evm_address::EvmAddress
};

use abi::FungibleToken;
use errors::Error;
use events::{MintedEvent, BurnedEvent};

storage {
    owner: ContractId,
    state: u64,
}

impl FungibleToken for Contract {

    fn constructor(owner: ContractId) -> bool {
        require(storage.state == 0, Error::CannotReinitialize);
        storage.owner = owner;
        storage.state = 1;
        true
    }

    fn mint(to: Sender, amount: u64) -> bool {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        match sender.unwrap() {
            Sender::ContractId(address) => {
                require(storage.owner == address, Error::UnauthorizedUser);

                match to {
                    Sender::Address(address) => {
                        mint_to_address(amount, address);
                    },
                    Sender::ContractId(address) => {
                        mint_to_contract(amount, address);
                    }
                }
            },
            _ => revert(42),
        }

        log(MintedEvent {to, amount});

        true
    }

    fn burn(from: Sender, amount: u64) -> bool {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        match sender.unwrap() {
            Sender::ContractId(address) => {
                require(storage.owner == address, Error::UnauthorizedUser);
                require(contract_id() == msg_asset_id(), Error::IncorrectAssetDeposited);
                require(amount == msg_amount(), Error::IncorrectAssetAmount);
                burn(amount);
            },
            _ => revert(42),
        }

        log(BurnedEvent {from, amount});

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
