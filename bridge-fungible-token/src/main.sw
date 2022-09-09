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
    chain::auth::{AuthError, msg_sender},
    constants::ZERO_B256,
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    identity::Identity,
    inputs::{input_pointer, input_type, Input},
    logging::log,
    option::Option,
    result::Result,
    revert::{revert, require},
    storage::StorageMap,
    token::{burn, mint, transfer_to_output},
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};
use utils::{input_message_data, input_message_data_length, input_message_sender, input_message_recipient};

////////////////////////////////////////
// Constants
////////////////////////////////////////

// @todo update with actual predicate root
const PREDICATE_ROOT = 0x0000000000000000000000000000000000000000000000000000000000000000;
const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 9u8;
// @todo update with actual L1 token address
const LAYER_1_TOKEN = ~EvmAddress::from(ZERO_B256);
const LAYER_1_ERC20_GATEWAY = ~EvmAddress::from(ZERO_B256);
const LAYER_1_DECIMALS = 18u8;

////////////////////////////////////////
// Data
////////////////////////////////////////

/**
bytes memory data =
            abi.encodePacked(
                fuelTokenId,
                bytes32(uint256(uint160(tokenId))),
                bytes32(uint256(uint160(msg.sender))), //from
                to,
                bytes32(amount)
            );
*/

struct MessageData {
    fuel_token: ContractId,
    asset: b256,
    from: b256,
    to: Address,
    amount: U256,
}

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    // @review what is needed !
    counter: u64 = 0,
    data1: ContractId = ~ContractId::from(ZERO_B256),
    data2: u64 = 0,
    data3: b256 = ZERO_B256,
    data4: Address = ~Address::from(ZERO_B256),
    ///
    initialized: bool = false,
    owner: Option<Identity> = Option::None,
    refund_amounts: StorageMap<(b256, b256), U256> = StorageMap {
    },
}

////////////////////////////////////////
// Private functions
////////////////////////////////////////

fn parse_message_data(msg_idx: u8) -> MessageData {
        // Parse the message data
        let data_length = input_message_data_length(msg_idx);
        if (data_length >= 32) {
            let id: b256 = input_message_data(msg_idx, 0);
            storage.data1 = ~ContractId::from(id);
        }
        if (data_length >= 32 + 8) {
            let num: u64 = input_message_data(msg_idx, 32);
            storage.data2 = num;
        }
        if (data_length >= 32 + 8 + 32) {
            let big_num: b256 = input_message_data(msg_idx, 32 + 8);
            storage.data3 = big_num;
        }
        if (data_length >= 32 + 8 + 32 + 32) {
            let address: b256 = input_message_data(msg_idx, 32 + 8 + 32);
            storage.data4 = ~Address::from(address);
        }
        // @todo populate and return MessageData
        MessageData {
            asset: 0x0000000000000000000000000000000000000000000000000000000000000000,
            fuel_token: contract_id(),
            to: ~Address::from(0x0000000000000000000000000000000000000000000000000000000000000000),
            amount: ~U256::from(0, 0, 0, 42)
        }
}

// ref: https://github.com/FuelLabs/fuel-specs/blob/bd6ec935e3d1797a192f731dadced3f121744d54/specs/vm/instruction_set.md#smo-send-message-to-output
fn send_message(recipient: Address, coins: u64) {
    // @todo implement me!
}

fn transfer_tokens(amount: u64, asset: ContractId, to: Address) {
    transfer_to_output(amount, asset, to)
}

#[storage(read)]
fn mint_tokens(amount: u64) -> bool {
    let sender = msg_sender().unwrap();
    let owner = storage.owner.unwrap();
    require(sender == owner, BridgeFungibleTokenError::UnauthorizedUser);
    mint(amount);
    log(MintEvent {from: msg_sender().unwrap(), amount});
    true
}

#[storage(read)]
fn burn_tokens(amount: u64) {
    let sender = msg_sender().unwrap();
    let owner = storage.owner.unwrap();
    require(sender == owner, BridgeFungibleTokenError::UnauthorizedUser);

    require(contract_id() == msg_asset_id(), BridgeFungibleTokenError::IncorrectAssetDeposited);
    require(amount == msg_amount(), BridgeFungibleTokenError::IncorrectAssetAmount);

    burn(amount);
    log(BurnEvent {from: msg_sender().unwrap(), amount})
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

// Implement the process_message function required to be a message receiver
impl MessageReceiver for Contract {

    #[storage(read, write)]
    fn process_message(msg_idx: u8) {
        // @review access control
        // @review can't directly compare type to Input::Message in an assert or require
        // assert(input_type(1) == Input::Message);
        let type = input_type(1);
        match type {
            Input::Message => {
                ();
            },
            _ => {
                revert(0);
            }
        }


        let message_sender = input_message_sender(1);

        // verify message_sender is the L1ERC20Gateway contract
        require(~EvmAddress::from(message_sender.value) == LAYER_1_ERC20_GATEWAY, BridgeFungibleTokenError::UnauthorizedUser);

        // Parse message data
        let message_data = parse_message_data(msg_idx);

        // @review requirement
        // verify asset matches hardcoded L1 token
        require(message_data.asset == LAYER_1_TOKEN.value, BridgeFungibleTokenError::IncorrectAssetDeposited);

        // verify value sent as uint256 can fit inside a u64
        // if not, register a refund.
        let l1_amount = message_data.amount.as_u64();
        match l1_amount {
            // @review is message_data.to the corrrect value to use here?
            Result::Err(e) => {
                storage.refund_amounts.insert((message_data.to.value, message_data.asset), message_data.amount);
                // @review should we propogate an error here ?
            },
            Result::Ok(v) => {
                mint_tokens(v);
                transfer_tokens(v, contract_id(), message_sender);
                log(MintEvent {
                    from: Identity::Address(message_sender),
                    amount: v,
                });
            },
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    fn constructor(owner: Identity) {
        require(storage.initialized == false, BridgeFungibleTokenError::CannotReinitialize);
        storage.owner = Option::Some(owner);
        storage.initialized = true;
    }

    #[storage(read, write)]
    // @review can anyone can call this, or only the originator themselves?
    fn claim_refund(originator: Identity, asset: ContractId) {
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

        let amount = storage.refund_amounts.get((inner_value, asset.into()));
        transfer_tokens(amount.as_u64().unwrap(), asset, ~Address::from(inner_value));
    }

    #[storage(read)]
    fn withdraw_to(to: Identity) {
        let withdrawal_amount = msg_amount();
        // @todo review requirement
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        let addr = match to {
            Identity::Address(a) => {
                a
            },
            Identity::ContractId => {
                revert(0);
            },
        };

        let origin_contract_id = msg_asset_id();
        burn_tokens(withdrawal_amount);

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
        LAYER_1_TOKEN
    }

    fn layer1_decimals() -> u8 {
        LAYER_1_DECIMALS
    }

}
