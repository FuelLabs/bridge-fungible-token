library events;

use std::{
    contract_id::ContractId,
    identity::Identity,
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};

pub struct BurnEvent {
    from: Identity,
    amount: u64,
}

pub struct RefundRegisteredEvent {
    from: EvmAddress,
    asset: EvmAddress,
    amount: b256,
}

pub struct MintEvent {
    amount: u64,
    to: Address,
}

pub struct TransferEvent {
    from: Identity,
    to: Identity,
    amount: u64,
}

pub struct WithdrawalEvent {
    to: b256,
    amount: u64,
    asset: ContractId,
}
