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
    register_refund,
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

        require(message_data.l1_asset == ~EvmAddress::from(LAYER_1_TOKEN), BridgeFungibleTokenError::IncorrectAssetDeposited);

        if message_data.l1_asset != ~EvmAddress::from(LAYER_1_TOKEN)
        {
            // Register a refund if tokens don't match. The L1 tokens are now locked in the contract on Ethereum, so reverting here is not the correct action as it would prevent the registration of a claimable refund on the Fuel side of the bridge.
            register_refund(message_data.from, message_data.l1_asset, amount);
        } else {
            // The value needs to be converted from the Ethereum side decimals (18) into the Fuel side decimals (9).
            // This could result in a refund (value too large to fit in u64 under new decimals or too small to fit in new decimals)
            /**
                So, "1" erc20 token is represented internally (in ethereum contract) as 1 * 10^18 or 1_000_000_000_000_000_000
                Dividing this number by 10^9 (because of 9 decimals in fuel contract) results in 1_000_000_000 internally, which is "1" token in the fuel contract
                Internal Representations:
                Ethereum: 1 = 0.000_000_000_000_000_001 ether (1 wei)
                Fuel:     1 = 0.000_000_001 Base Asset
                so: 999_999_999 wei sent from ethereum to fuel would result in a refund because it's too small to fit in the 9 decimals observed in the L2 BridgeFungibleToken contract, because this would be
                              `0.000_000_000_999_999_999`, when
                              `0.000_000_001` is the smallest value we can work with at 9 decimals.
            */

            let decomposed = decompose(message_data.amount);
            let amount = ~U256::from(decomposed.0, decomposed.1, decomposed.2, decomposed.3);
            let l1_amount_opt = amount.as_u64();
            match l1_amount_opt {
                Result::Err(e) => {
                    register_refund(message_data.from, message_data.l1_asset, amount);
                },
                Result::Ok(amount) => {
                    mint_tokens(amount, Identity::Address(message_data.to));
                    transfer_tokens(amount, contract_id(), Identity::Address(message_data.to));
                },
            }
        }
    }
}

impl BridgeFungibleToken for Contract {
    #[storage(read, write)]
    fn claim_refund(originator: EvmAddress, asset: EvmAddress) {
        let stored_amount = storage.refund_amounts.get((
            originator,
            asset,
        ));
        // reset the refund amount to 0
        storage.refund_amounts.insert((originator, asset), ZERO_B256);
        // send a message to unlock this amount on the ethereum (L1) bridge contract contract
        send_message(originator, asset, stored_amount);
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
