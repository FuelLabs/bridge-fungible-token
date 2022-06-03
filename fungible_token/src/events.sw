library events;

use std::chain::auth::Sender;

pub struct MintedEvent {
    to: Sender,
    amount: u64,
}

pub struct BurnedEvent {
    from: Sender,
    amount: u64,
}
