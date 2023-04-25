contract;

use contract_message_receiver::MessageReceiver;

storage {
    val: bool = false,
}

abi DepositRecipient {
    #[storage(read)]
    fn get_stored_val() -> bool;
}

impl MessageReceiver for Contract {
    #[storage(read, write)]
    #[payable]
    fn process_message(msg_idx: u8) {}
}

impl DepositRecipient for Contract {
    #[storage(read)]
    fn get_stored_val() -> bool {
        storage.val.read()
    }
}
