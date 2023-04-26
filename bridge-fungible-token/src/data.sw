library;

pub struct MessageData {
    token: b256,
    from: b256,
    to: Identity,
    amount: b256,
    deposit_to_contract: bool,
    len: u64,
}
