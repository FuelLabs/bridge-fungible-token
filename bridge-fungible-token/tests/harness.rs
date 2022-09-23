mod utils {
    pub mod environment;
    pub mod ext_fuel_core;
    pub mod ext_sdk_provider;
}

use utils::environment as env;
use utils::ext_fuel_core;
use utils::ext_sdk_provider;

use fuels::test_helpers::DEFAULT_COIN_AMOUNT;
use fuels::tx::{Address, AssetId, Bytes32, ContractId, Output};

pub const L1_TOKEN: &str = "0xabcdef0000000000000000000000000000000000000000000000000000abcdef";
pub const TO: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const AMOUNT: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";

mod success {
    use super::*;

    #[tokio::test]
    async fn relay_message_with_predicate_and_script_constraint() {
        let (_, _, root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;

        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut root_array.to_vec());
        message_data.append(&mut env::decode_hex(TO));
        message_data.append(&mut env::decode_hex(AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (wallet, test_contract, contract_input, coin_inputs, message_inputs) =
            env::setup_environment(vec![coin], vec![message]).await;

        let new_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![new_output],
        )
        .await;

        // Verify the message value was received by the test contract
        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract._get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }
}

mod revert {
    use super::*;

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_token() {
        let (_, _, root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;
        let wrong_token_value: &str =
            "0x1111110000000000000000000000000000000000000000000000000000111111";
        let mut message_data = Vec::with_capacity(5);
        // append incorrect L1 token to data:
        message_data.append(&mut env::decode_hex(wrong_token_value));
        message_data.append(&mut root_array.to_vec());
        message_data.append(&mut env::decode_hex(TO));
        message_data.append(&mut env::decode_hex(AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (wallet, test_contract, contract_input, coin_inputs, message_inputs) =
            env::setup_environment(vec![coin], vec![message]).await;

        let new_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![new_output],
        )
        .await;

        // Verify the message value was received by the test contract
        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract._get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_predicate_root() {
        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        let wrong_predicate_root =
            "0x1111110000000000000000000000000000000000000000000000000000111111";
        // append incorrect predicate root to data:
        message_data.append(&mut env::decode_hex(wrong_predicate_root));
        message_data.append(&mut env::decode_hex(TO));
        message_data.append(&mut env::decode_hex(AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (wallet, test_contract, contract_input, coin_inputs, message_inputs) =
            env::setup_environment(vec![coin], vec![message]).await;

        let new_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![new_output],
        )
        .await;

        // Verify the message value was received by the test contract
        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract._get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_to_value() {
        let (_, _, root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;
        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut root_array.to_vec());
        let wrong_to_value = "0x1111110000000000000000000000000000000000000000000000000000111111";
        // append incorrect `to` value to data:
        message_data.append(&mut env::decode_hex(wrong_to_value));
        message_data.append(&mut env::decode_hex(AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (wallet, test_contract, contract_input, coin_inputs, message_inputs) =
            env::setup_environment(vec![coin], vec![message]).await;

        let new_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![new_output],
        )
        .await;

        // Verify the message value was received by the test contract
        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract._get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }
}
