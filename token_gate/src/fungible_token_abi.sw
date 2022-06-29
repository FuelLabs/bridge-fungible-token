librbary fungible_token_abi;

use std::identity::Identity;

abi FungibleToken {
    #[storage(read, write)]
    fn constructor(owner: Identity);
    #[storage(read, write)]
    fn mint(to: Identity, amount: u64);
    #[storage(read, write)]
    fn burn(amount: u64);
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
}
