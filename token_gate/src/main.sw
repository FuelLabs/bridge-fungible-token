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

const PREDICATE_ROOT = ~b256::min();
const NAME = "Placeholder";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 18;
const LAYER_1_TOKEN = ~EvmAddress::from(~b256::min());
const LAYER_1_DECIMALS = 18;

////////////////////////////////////////
// Data
////////////////////////////////////////

struct Message {
    asset: ContractId,
    fuel_token: ContractId,
    to: Identity,
    amount: u64,
}

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    initialized: bool,
    owner: Identity,
    refund_amounts: StorageMap<(b256, b256), u64>,
}

////////////////////////////////////////
// Helper functions
////////////////////////////////////////

/// Check if the owner of an InputMessage matches PREDICATE_ROOT
fn authenticate_message_owner() -> bool {
    let target_input_type = 2u8;
    let inputs_count = tx_inputs_count();

    let mut i = 0u64;

    while i < inputs_count {
        let input_pointer = tx_input_pointer(i);
        let input_type = tx_input_type(input_pointer);
        if input_type != target_input_type {
            // type != InputMessage
            // Continue looping.
            i = i + 1;
        } else {
            let input_owner = Option::Some(tx_input_coin_owner(input_pointer));
            if input_owner.unwrap() == PREDICATE_ROOT {
                true
            } else {
                // owner not matching
                i = i + 1;
            }
        }
    }
    false
}

                // Compare current coin owner to candidate.
                // `candidate` and `input_owner` must be `Option::Some` at this point,
                // so can unwrap safely.
                // if input_owner.unwrap() == candidate.unwrap() {
                    // Owners are a match, continue looping.
                    // i = i + 1;
                // } else {
                    // Owners don't match. Return Err.
                    // i = inputs_count;
                    // return Result::Err(AuthError::InputsNotAllOwnedBySameAddress);



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
}

abi L2ERC20Gateway {
    fn withdraw_refund(originator: Identity);
    fn withdraw_to(to: Identity);
    fn finalize_deposit();
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}

////////////////////////////////////////
// Errors
////////////////////////////////////////

enum TokenGatewayError {
    CannotReinitialize: (),
    ContractNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
    NoCoinsForwarded: (),
    IncorrectMessageOwner: (),
}

////////////////////////////////////////
// Events
////////////////////////////////////////

pub struct MintEvent {
    to: Identity,
    amount: u64,
}

pub struct BurnEvent {
    from: Identity,
    amount: u64,
}

struct WithdrawalEvent {
    to: Identity,
    amount: u64,
    asset: ContractId,
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

impl FungibleToken for Contract {
    ///  owner is the L1ERC20Gateway contract ?
    fn constructor(owner: Identity) {
        require(storage.initialized == false, TokenError::CannotReinitialize);
        storage.owner = owner;
        storage.initialized = true;
    }

    // @todo decide if this needs to be public
    fn mint(to: Identity, amount: u64) {
        require(msg_sender().unwrap() == storage.owner, TokenError::UnauthorizedUser);
        mint_to(amount, to);
        log(MintedEvent {to, amount});
    }

    // @todo decide if this needs to be public
    fn burn(from: Identity, amount: u64) {
        require(msg_sender().unwrap() == storage.owner, TokenError::UnauthorizedUser);
        require(contract_id() == msg_asset_id(), TokenError::IncorrectAssetDeposited);
        require(amount == msg_amount(), TokenError::IncorrectAssetAmount);

        burn(amount);
        log(BurnedEvent {from, amount});
    }

    fn name() -> str[11] {
        NAME
    }

    fn symbol() -> str[11] {
        SYMBOL
    }

    fn decimals() -> u8 {
        DECIMALS
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

        log(WithdrawalEvent {
            to: to,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
    }

    fn finalize_deposit() {
        // verify msg_sender is the L1ERC20Gateway contract
        let sender = msg_sender();
        require(sender == storage.owner, TokenGatewayError::UnauthorizedUser);


        // Verify first message owner input predicate == ERC20GatewayDepositPredicate
        // check that first masessage-input owner == predicate root (which must be hardcoded in this contract)
        require(authenticate_message_owner(), TokenGatewayError::IncorrectMessageOwner);

        // Parse message data (asset: ContractId, fuel_token: ContractId, to: Identity, amount: u64)

        let messsage: Message = Message {
            asset:
            fuel_token:
            to:
            amount:
        };

        // verify asset matches hardcoded L1 token
        require(asset == LAYER_1_TOKEN, TokenError::IncorrectAssetDeposited);

        // start token mint process
        // if mint fails or is invalid for any reason (i.e: precision), register it to be refunded later
    }

    fn layer1_token() -> EvmAddress {
        LAYER_1_TOKEN
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}
