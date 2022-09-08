library bridge_fungible_token_abi;

use std::address::Address;
use std::contract_id::ContractId;

abi BridgeFungibleToken {
    // @review do we still need a constructor?
    #[storage(read, write)]fn constructor(owner: Identity);
    #[storage(read, write)]fn claim_refund(originator: Identity, asset: ContractId);

    /// Withdraw coins back to L1 and burn the corresponding amount of coins
    /// on L2.
    ///
    /// # Arguments
    ///
    /// * `to` - the destination of the transfer (an Address or a ContractId)
    ///
    /// # Reverts
    ///
    /// * When no coins were sent with call
    fn withdraw_to(to: Identity);
    // @review is this now handled by process_message()?
    #[storage(read, write)]fn finalize_deposit();
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}
