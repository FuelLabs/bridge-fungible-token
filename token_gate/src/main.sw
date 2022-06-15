contract;

use std::{chain::auth::Sender, contract_id::Identity, vm::evm::evm_address::EvmAddress};

////////////////////////////////////////
// Constants
////////////////////////////////////////

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

////////////////////////////////////////
// Helper functions
////////////////////////////////////////

////////////////////////////////////////
// ABI definitions
////////////////////////////////////////

abi FungibleToken {
    fn constructor(owner: Identity) -> bool;
    fn mint(to: Identity, amount: u64) -> bool;
    fn burn(from: Identity, amount: u64) -> bool;
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}

abi L2ERC20Gateway {

}

////////////////////////////////////////
// Errors
////////////////////////////////////////

pub enum Error {
    CannotReinitialize: (),
    StateNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
}

////////////////////////////////////////
// Events
////////////////////////////////////////

pub struct MintedEvent {
    to: Identity,
    amount: u64,
}

pub struct BurnedEvent {
    from: Identity,
    amount: u64,
}

impl FungibleToken for Contract {
    fn test_function() -> bool {
        true
    }
}

impl L2ERC20Gateway for Contract {
    fn test_function() -> bool {
        true
    }
}
