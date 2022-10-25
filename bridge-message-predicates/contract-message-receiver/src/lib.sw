library message_receiver;

abi MessageReceiver {
    #[storage(write)]fn process_message(msg_idx: u8);
}
