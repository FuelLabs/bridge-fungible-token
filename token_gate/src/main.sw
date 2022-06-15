contract;

use std::{
    address::Address,
    assert::require,
    chain::auth::{AuthError, msg_sender},
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    identity::Identity,
    logging::log,
    result::*,
    revert::revert,
    token::{mint_to, burn},
    vm::evm::evm_address::EvmAddress
};

////////////////////////////////////////
// Constants
////////////////////////////////////////

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    initialized: bool,
    // @todo rethink storing Identities.
    owner: Identity,
    refund_amounts: StorageMap<(b256, b256), u64>,
}

////////////////////////////////////////
// Helper functions
////////////////////////////////////////

fn caller_is_owner() -> bool {
    let sender: Result<Sender, AuthError> = msg_sender();
    match sender.unwrap() {
        Identity::ContractId(id) => {
            if storage.owner == id {
                true
            } else {
                false
            }
        },
        // we restrict access to the correct contract only
        _ => false,
    }
}

fn process_message() {
    // Finalize deposit
    // Verify first message input owner predicate == MessageToGatewayPredicate
    // Verify the msg sender is the L1ERC20Gateway contract
    // *predicate will have already verified only 1 message input
    // *predicate will have already verified this contract is supposed to receive mesage
    // * no value will be sent by the L1ERC20Gateway contract
}

////////////////////////////////////////
// ABI definitions
////////////////////////////////////////

abi FungibleToken {
    fn constructor(owner: Identity);
    fn mint(to: Identity, amount: u64);
    fn burn(from: Identity, amount: u64);
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}

abi L2ERC20Gateway {
    fn withdraw_refund(originator: Identity);
    fn withdraw_to(to: Identity);
    fn finalize_deposit();
}

////////////////////////////////////////
// Errors
////////////////////////////////////////

enum TokenError {
    CannotReinitialize: (),
    ContractNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
}

enum GatewayError {
    NoCoinsForwarded: (),
}

////////////////////////////////////////
// Events
////////////////////////////////////////

pub struct MintedEvent {
    to: Identity,
    amount: u64,
}

pub struct BurnedEvent {
    from: Identity,
    amount: u64,
}

struct Withdrawal {
    to: Identity,
    amount: u64,
    asset: ContractId,
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

impl FungibleToken for Contract {
    fn constructor(owner: ContractId) {
        require(storage.initialized == false, TokenError::CannotReinitialize);
        storage.owner = owner;
        storage.initialized = true;
    }

    // @todo decide if this needs to be public
    fn mint(to: Identity, amount: u64) {
        require(caller_is_owner(), TokenError::UnauthorizedUser);
        mint_to(amount, to);
        log(MintedEvent {to, amount});
    }

    // @todo decide if this needs to be public
    fn burn(from: Identity, amount: u64) {
        require(caller_is_owner(), TokenError::UnauthorizedUser);
        require(contract_id() == msg_asset_id(), TokenError::IncorrectAssetDeposited);
        require(amount == msg_amount(), TokenError::IncorrectAssetAmount);

        burn(amount);
        log(BurnedEvent {from, amount});
    }

    fn name() -> str[11] {
        "placeholder"
    }

    fn symbol() -> str[11] {
        "placeholder"
    }

    fn decimals() -> u8 {
        2
    }

    fn layer1_token() -> EvmAddress {
        ~EvmAddress::from(~b256::min())
    }

    fn layer1_decimals() -> u8 {
        2
    }
}

impl L2ERC20Gateway for Contract {
    fn withdraw_refund(originator: Identity) {}

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
    fn withdraw_to(to: Identity) {
        let withdrawal_amount = balance();
        require(withdrawal_amount != 0, GatewayError::NoCoinsForwarded);
        let origin_contract_id = msg_asset_id();
        // Verify this contract can burn these coins ???
        let token_contract = abi(FungibleToken, origin_contract_id);

        token_contract.burn{
            coins: withdrawal_amount,
            asset_id: origin_contract_id
        } (withdrawal_amount);

        // @todo implement me!
        // Output a message to release tokens locked on L1
        // send_message(...);
        log(withdrawal);
    }

    fn finalize_deposit() {
        // verify msg_sender is the L1ERC20Gateway contract
        let sender: Result<Identity, AuthError> = msg_sender();
        match sender.unwrap() {

        }


        // Verify first message owner input predicate == ERC20GatewayDepositPredicate
        // * predicate will have already verified only 1 msg input
        // * predicate will have already verified this contract is supposed to recieve message

        // Parse messsage data (asset: ContractId, fuel_token: ContractId, to: Identity, amount: u64)

        // verify asset matches hardcoded L1 token
        // start token mint process
        // if mint fails or is invalid for any reason (i.e: precision), register it to be refunded later
    }
}
