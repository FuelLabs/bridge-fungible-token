library bridge_fungible_token_abi;

use std::{contract_id::ContractId, identity::Identity, vm::evm::evm_address::EvmAddress};

abi BridgeFungibleToken {
    /// Claim a refund for an EvmAddress if one has been registered.
    ///
    /// # Arguments
    ///
    /// * `originator` - the EvmAddress that is entitled to a refund
    /// * `asset` - the EvmAddress of the L1 token for the refund
    #[storage(read, write)]
    fn claim_refund(originator: b256, asset: b256);

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
    /// * When the wrong asset was sent with the call
    #[storage(read)]
    fn withdraw_to(to: b256);
    /// Get the name of this token contract
    fn name() -> str[8];
    /// Get the symbol of this token contract
    fn symbol() -> str[5];
    /// get the decimals of this token contract
    fn decimals() -> u8;
    /// get the L1 token that this contract bridges
    fn layer1_token() -> b256;
    /// get the L1_decimals of this token contract
    fn layer1_decimals() -> u8;
}
