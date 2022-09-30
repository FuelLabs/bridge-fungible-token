library bridge_fungible_token_abi;

use std::{contract_id::ContractId, identity::Identity, vm::evm::evm_address::EvmAddress};

abi BridgeFungibleToken {
    #[storage(read, write)]
    fn claim_refund(originator: EvmAddress, asset: EvmAddress);

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
    #[storage(read)]
    fn withdraw_to(to: Identity);
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}
