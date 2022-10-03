library events;

use std::{contract_id::ContractId, identity::Identity};

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
    to: Identity,
    amount: u64,
}

pub struct TransferEvent {
    from: Identity,
    to: Identity,
    amount: u64,
}

pub struct WithdrawalEvent {
    to: Identity,
    amount: u64,
    asset: ContractId,
}
