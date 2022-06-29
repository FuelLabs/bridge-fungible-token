library gateway_abi;

abi L2ERC20Gateway {
    fn withdraw_refund(originator: Identity);
    fn withdraw_to(to: Identity);
    #[storage(read, write)]
    fn finalize_deposit();
    // @todo should return EvmAddress !
    fn layer1_token() -> Address;
    fn layer1_decimals() -> u8;
}
