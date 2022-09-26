library data;

use std::{address::Address, contract_id::ContractId, vm::evm::evm_address::EvmAddress};

pub struct MessageData {
    fuel_token: ContractId,
    l1_asset: EvmAddress,
    from: Address,
    to: Address,
    amount: b256,
}
