library abi;

use std::{chain::auth::Sender, contract_id::ContractId, vm::evm::evm_address::EvmAddress};

abi FungibleToken {
    fn constructor(owner: ContractId) -> bool;
    fn mint(to: Sender, amount: u64) -> bool;
    fn burn(from: Sender, amount: u64) -> bool;
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}
