library events;

use std::{
    contract_id::ContractId,
    identity::Identity,
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};

pub struct RefundRegisteredEvent {
    from: EvmAddress,
    asset: EvmAddress,
    amount: b256,
}

pub struct MintEvent {
    amount: u64,
    to: Address,
}

pub struct WithdrawalEvent {
    to: b256,
    from: Identity,
    amount: u64,
    asset: ContractId,
}
