library gateway_abi;

use std::{vm::evm::evm_address::EvmAddress, contract_id::ContractId, identity::Identity};

abi L2ERC20Gateway {
    #[storage(read, write)]fn constructor(owner: Identity);
    #[storage(read, write)]fn claim_refund(originator: Identity, asset: ContractId);
    fn withdraw_to(to: Identity);
    #[storage(read, write)]fn finalize_deposit();
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;

}
