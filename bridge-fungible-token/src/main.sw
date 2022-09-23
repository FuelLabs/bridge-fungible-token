contract;

dep data;
dep errors;
dep events;
dep utils;

use bridge_fungible_token_abi::BridgeFungibleToken;
use contract_message_receiver::MessageReceiver;
use core::num::*;
// use data::MessageData;
use errors::BridgeFungibleTokenError;
use events::WithdrawalEvent;
use std::{
    address::Address,
    assert::assert,
    chain::auth::{
        AuthError,
        msg_sender,
    },
    context::{
        call_frames::{
            contract_id,
            msg_asset_id,
        },
        msg_amount,
    },
    contract_id::ContractId,
    identity::Identity,
    logging::log,
    option::Option,
    result::Result,
    revert::{
        require,
        revert,
    },
    storage::StorageMap,
    u256::U256,
    vm::evm::evm_address::EvmAddress,
};
use utils::{
    decompose,
    input_message_data,
    input_message_data_length,
    input_message_recipient,
    input_message_sender,
    mint_tokens,
    burn_tokens,
    transfer_tokens,
    send_message,
    parse_message_data,
    correct_input_type,
    is_address,
};

////////////////////////////////////////
// Constants
////////////////////////////////////////

const NAME = "PLACEHOLDER";
const SYMBOL = "PLACEHOLDER";
const DECIMALS = 9u8;
const LAYER_1_DECIMALS = 18u8;

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    refund_amounts: StorageMap<(b256, EvmAddress), U256> = StorageMap {},
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

// Implement the process_message function required to be a message receiver
impl MessageReceiver for Contract {
    #[storage(read, write)]
    fn process_message(msg_idx: u8) {
        let input_sender = input_message_sender(1);

        require(input_sender.value == LAYER_1_ERC20_GATEWAY, BridgeFungibleTokenError::UnauthorizedUser);

        let message_data = parse_message_data(msg_idx);

        // @review verify asset matches hardcoded L1 token
        require(message_data.l1_asset == ~EvmAddress::from(LAYER_1_TOKEN), BridgeFungibleTokenError::IncorrectAssetDeposited);

        // check that value sent as uint256 can fit inside a u64, else register a refund.
        let decomposed = decompose(message_data.amount);
        let amount = ~U256::from(decomposed.0, decomposed.1, decomposed.2, decomposed.3);
        let l1_amount_opt = amount.as_u64();
        match l1_amount_opt {
            Result::Err(e) => {
                storage.refund_amounts.insert((
                    message_data.to.value,
                    message_data.l1_asset,
                ), amount);
                // @review emit event (i.e: `DepositFailedEvent`) here to allow the refund process to be initiated?
            },
            Result::Ok(v) => {
                mint_tokens(v, Identity::Address(input_sender));
                log(555);
                transfer_tokens(v, contract_id(), input_sender);
            },
        }
    }
}

impl BridgeFungibleToken for Contract {
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
        transfer_tokens(amount.as_u64().unwrap(), ~ContractId::from(asset.value), ~Address::from(inner_value));
    }

    #[storage(read)]
    fn withdraw_to(to: Identity) {
        let withdrawal_amount = msg_amount();
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        require(is_address(to), BridgeFungibleTokenError::NotAnAddress);

        let origin_contract_id = msg_asset_id();
        let sender = msg_sender().unwrap();

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
