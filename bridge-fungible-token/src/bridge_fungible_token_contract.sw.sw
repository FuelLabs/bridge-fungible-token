contract;

dep data;
dep errors;
dep events;
dep utils;

use bridge_fungible_token_abi::BridgeFungibleToken;
use contract_message_receiver::MessageReceiver;
use core::num::*;
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
    burn_tokens,
    correct_input_type,
    decompose,
    input_message_data,
    input_message_data_length,
    input_message_recipient,
    input_message_sender,
    is_address,
    mint_tokens,
    parse_message_data,
    send_message,
    transfer_tokens,
};

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////
storage {
    refund_amounts: StorageMap<(EvmAddress, EvmAddress), U256> = StorageMap {},
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

        // @todo issue a refund if tokens don't match
        require(message_data.l1_asset == ~EvmAddress::from(LAYER_1_TOKEN), BridgeFungibleTokenError::IncorrectAssetDeposited);

        // check that value sent as uint256 can fit inside a u64, else register a refund.
        let decomposed = decompose(message_data.amount);
        let amount = ~U256::from(decomposed.0, decomposed.1, decomposed.2, decomposed.3);
        let l1_amount_opt = amount.as_u64();
        match l1_amount_opt {
            Result::Err(e) => {
                storage.refund_amounts.insert((
                    message_data.from,
                    message_data.l1_asset,
                ), amount);
                // @review emit event (i.e: `DepositFailedEvent`) here to allow the refund process to be initiated?
            },
            Result::Ok(amount) => {
                mint_tokens(amount, Identity::Address(message_data.to));
                transfer_tokens(amount, contract_id(), Identity::Address(message_data.to));
            },
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    // @review can anyone can call this on behalf of the originator, or only the originator themselves?
    fn claim_refund(originator: EvmAddress, asset: EvmAddress) {
        let amount = storage.refund_amounts.get((
            originator,
            asset,
        ));
        send_message(originator, amount);
    }

    #[storage(read)]
    fn withdraw_to(to: EvmAddress) {
        let withdrawal_amount = msg_amount();
        require(withdrawal_amount != 0, BridgeFungibleTokenError::NoCoinsForwarded);

        let origin_contract_id = msg_asset_id();
        let sender = msg_sender().unwrap();

        // check that the correct asset was sent with call
        require(contract_id() == origin_contract_id, BridgeFungibleTokenError::IncorrectAssetDeposited);

        burn_tokens(withdrawal_amount, sender);
        send_message(to, withdrawal_amount);
        log(WithdrawalEvent {
            to: to,
            amount: withdrawal_amount,
            asset: origin_contract_id,
        });
    }

    fn name() -> str[8] {
        NAME
    }

    fn symbol() -> str[5] {
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
