contract;

dep utils;
dep errors;
dep events;

use bridge_fungible_token_abi::BridgeFungibleToken;
use contract_message_receiver::MessageReceiver;
use core::num::*;
use errors::BridgeFungibleTokenError;
use events::{BurnEvent, MintEvent, TransferEvent, WithdrawalEvent};
use std::{
    address::Address,
    assert::assert,
    chain::auth::{
        AuthError,
        msg_sender,
    },
    constants::ZERO_B256,
    context::{
        call_frames::{
            contract_id,
            msg_asset_id,
        },
        msg_amount,
    },
    contract_id::ContractId,
    identity::Identity,
    inputs::{
        Input,
        input_pointer,
        input_type,
    },
    logging::log,
    option::Option,
    result::Result,
    revert::{
        require,
        revert,
    },
    storage::StorageMap,
    token::{
        burn,
        mint,
        transfer_to_output,
    },
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};
use utils::{
    decompose,
    input_message_data,
    input_message_data_length,
    input_message_recipient,
    input_message_sender,
};

////////////////////////////////////////
// Constants
////////////////////////////////////////

const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 9u8;
const LAYER_1_DECIMALS = 18u8;

////////////////////////////////////////
// Data
////////////////////////////////////////

struct MessageData {
    fuel_token: ContractId,
    l1_asset: EvmAddress,
    from: Address,
    to: Address,
    amount: b256,
}

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    initialized: bool = false,
    owner: Option<Identity> = Option::None,
    refund_amounts: StorageMap<(b256, EvmAddress), u64> = StorageMap {},
}

////////////////////////////////////////
// Private functions
////////////////////////////////////////
fn is_address(val: Identity) -> bool {
    match val {
        Identity::Address(a) => {
            true
        },
        Identity::ContractId => {
            false
        },
    }
}

fn correct_input_type(index: u64) -> bool {
    let type = input_type(1);
    match type {
        Input::Message => {
            true
        },
        _ => {
            false
        }
    }
}

fn parse_message_data(msg_idx: u8) -> MessageData {
    let mut msg_data = MessageData {
        fuel_token: ~ContractId::from(ZERO_B256),
        l1_asset: ~EvmAddress::from(ZERO_B256),
        from: ~Address::from(ZERO_B256),
        to: ~Address::from(ZERO_B256),
        amount: ZERO_B256,
    };

    // Parse the message data
    // @review can we trust that message.data is long enough/has all required data (does predicate enforce this) ?
    msg_data.fuel_token = ~ContractId::from(input_message_data::<b256>(msg_idx, 0));
    msg_data.l1_asset = ~EvmAddress::from(input_message_data::<b256>(msg_idx, 32));
    msg_data.from = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32));
    msg_data.to = ~Address::from(input_message_data::<b256>(msg_idx, 32 + 32 + 32));
    msg_data.amount = input_message_data::<b256>(msg_idx, 32 + 32 + 32 + 32);

    msg_data
}

// ref: https://github.com/FuelLabs/fuel-specs/blob/bd6ec935e3d1797a192f731dadced3f121744d54/specs/vm/instruction_set.md#smo-send-message-to-output
fn send_message(recipient: Address, coins: u64) {
    // @todo implement me!
}

fn transfer_tokens(amount: u64, asset: ContractId, to: Address) {
    transfer_to_output(amount, asset, to)
}

#[storage(read)]
fn mint_tokens(amount: u64, from: Identity) -> bool {
    mint(amount);
    log(MintEvent {
        from: from,
        amount,
    });
    true
}

fn burn_tokens(amount: u64, from: Identity) {
    burn(amount);
    log(BurnEvent {
        from: from,
        amount,
    })
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////
// Implement the process_message function required to be a message receiver
impl MessageReceiver for Contract {
    #[storage(read, write)]
    fn process_message(msg_idx: u8) {
        require(correct_input_type(msg_idx), BridgeFungibleTokenError::IncorrectInputType);

        let input_sender = input_message_sender(1);

        // @todo should this be the predicate address instead of the root?
        require(input_sender.value == PREDICATE_ROOT, BridgeFungibleTokenError::UnauthorizedUser);

        let message_data = parse_message_data(msg_idx);

        // verify asset matches hardcoded L1 token
        require(message_data.l1_asset == ~EvmAddress::from(LAYER_1_TOKEN), BridgeFungibleTokenError::IncorrectAssetDeposited);

        // check that value sent as uint256 can fit inside a u64, else register a refund.
        let decomposed = decompose(message_data.amount);
        let l1_amount = ~U256::from(decomposed.0, decomposed.1, decomposed.2, decomposed.3).as_u64();
        match l1_amount {
            Result::Err(e) => {
                storage.refund_amounts.insert((
                    message_data.to.value,
                    message_data.l1_asset,
                ), l1_amount.unwrap());
                // @review emit event (i.e: `DepositFailedEvent`) here to allow the refund process to be initiated?
            },
            Result::Ok(v) => {
                let sender = msg_sender().unwrap();
                let owner = storage.owner.unwrap();
                // @review requirement !
                require(sender == owner, BridgeFungibleTokenError::UnauthorizedUser);
                mint_tokens(v, Identity::Address(input_sender));
                transfer_tokens(v, contract_id(), input_sender);
            },
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    // @review decide how to handle `owner`. If made a config-time const, we don't need this constructor, and can remove the `owner` and `initialized` fields from `storage`.
    fn constructor(owner: Identity) {
        require(storage.initialized == false, BridgeFungibleTokenError::CannotReinitialize);
        storage.owner = Option::Some(owner);
        storage.initialized = true;
    }

    #[storage(read, write)]
    // @review can anyone can call this, or only the originator themselves?
    fn claim_refund(originator: Identity, asset: EvmAddress) {
        // check storage mapping refund_amounts first
        // if valid, transfer to originator
        let inner_value = match originator {
            Identity::Address(a) => {
                a.value
            },
            Identity::ContractId(c) => {
                c.value
            },
        };

        let amount = storage.refund_amounts.get((
            inner_value,
            asset,
        ));
        transfer_tokens(amount, ~ContractId::from(asset.value), ~Address::from(inner_value));
    }

    #[storage(read)]
    fn withdraw_to(to: Identity) {
        let withdrawal_amount = msg_amount();
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        require(is_address(to), BridgeFungibleTokenError::NotAnAddress);

        let origin_contract_id = msg_asset_id();

        let sender = msg_sender().unwrap();
        let owner = storage.owner.unwrap();
        require(sender == owner, BridgeFungibleTokenError::UnauthorizedUser);
        require(contract_id() == msg_asset_id(), BridgeFungibleTokenError::IncorrectAssetDeposited);
        burn_tokens(withdrawal_amount, sender);

        let addr = match to {
            Identity::Address(a) => {
                a
            },
            Identity::ContractId => {
                revert(0);
            },
        };
        // Output a message to release tokens locked on L1
        send_message(addr, withdrawal_amount);

        log(WithdrawalEvent {
            to: to,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
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

    fn layer1_token() -> EvmAddress {
        ~EvmAddress::from(LAYER_1_TOKEN)
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }
}
