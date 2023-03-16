library data;

use std::{address::Address, contract_id::ContractId};

pub struct MessageData {
    token: b256,
    from: b256,
    to: Identity,
    amount: b256,
    deposit_to_contract: bool,
}
