mod utils {
    pub mod environment;
    pub mod ext_sdk_provider;
}

use std::str::FromStr;
use utils::environment as env;
use utils::ext_sdk_provider;

use fuels::prelude::*;
use fuels::test_helpers::DEFAULT_COIN_AMOUNT;
use fuels::tx::{Address, AssetId, Output};

pub const L1_TOKEN: &str = "0x00000000000000000000000000000000000000000000000000000000deadbeef";
pub const TO: &str = "0x0000000000000000000000000000000000000000000000000000000000000777";
pub const FROM: &str = "0x0000000000000000000000008888888888888888888888888888888888888888";
pub const MINIMUM_BRIDGABLE_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000000000000003B9ACA00";
pub const DUST: &str = "0x0000000000000000000000000000000000000000000000000000000000000011";
pub const MAXIMUM_BRIDGABLE_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000000FFFFFFFFFFFFFFFF";
pub const OVERFLOWING_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000001FFFFFFFFFFFFFFFF";

mod success {
    use super::*;

    #[tokio::test]
    async fn relay_message_with_predicate_and_script_constraint() -> Result<(), Error> {
        let (_, _, _root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;

        let mut recipient_wallet = WalletUnlocked::new_random(None);

        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        // @review from used to be the predicate root
        // message_data.append(&mut root_array.to_vec());
        message_data.append(&mut env::decode_hex(FROM));
        message_data.append(&mut recipient_wallet.address().hash().to_vec());
        message_data.append(&mut env::decode_hex(MINIMUM_BRIDGABLE_AMOUNT));

        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(vec![coin], vec![message], None).await;

        recipient_wallet.set_provider(provider);

        let variable_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };
        let message_output = Output::Message {
            recipient: Address::zeroed(),
            amount: 0,
        };

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![variable_output, message_output],
        )
        .await;

        let provider = wallet.get_provider().unwrap();
        let test_contract_base_asset_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();

        let balance = recipient_wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_base_asset_balance, 100);
        // Check that wallet now has bridged coins
        assert_eq!(balance, 1);
        Ok(())
    }

    #[tokio::test]
    #[ignore]
    async fn withdraw_from_bridge() {
        // perform successful deposit first, verify it, then withdraw and verify balances
    }

    #[tokio::test]
    #[ignore]
    async fn claim_refund() {
        // perform failing deposit first to register a refund, verify, then claim and verify L2 balances changed as expected. L1 nweeds to be checked as well in integration tests
    }

    #[tokio::test]
    // #[should_panic(expected = "Revert(42)")]
    async fn depositing_dust_registers_refund() -> Result<(), Error> {
        // "dust" here refers to any amount less than 1_000_000_000.
        // This is to account for conversion between the 18 decimals on most erc20 contracts, and the 9 decimals in the Fuel BridgeFungibleToken contract
        let (_, _, _root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;

        let mut recipient_wallet = WalletUnlocked::new_random(None);

        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut env::decode_hex(FROM));
        message_data.append(&mut recipient_wallet.address().hash().to_vec());
        message_data.append(&mut env::decode_hex(DUST));

        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(vec![coin], vec![message], None).await;

        recipient_wallet.set_provider(provider);

        let variable_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };
        let message_output = Output::Message {
            recipient: Address::zeroed(),
            amount: 0,
        };

        // Relay the test message to the test contract
        let receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![variable_output, message_output],
        )
        .await;

        let refund_registered_event = test_contract
            .logs_with_type::<utils::environment::bridgefungibletokencontract_mod::RefundRegisteredEvent>(
            &receipts,
        )?;

        // Verify the message value was received by the test contract
        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);

        let dust_addr: Address = Address::from_str(&DUST).unwrap();
        let l1_token_address: Address = Address::from_str(&L1_TOKEN).unwrap();
        let from_address: Address = Address::from_str(&FROM).unwrap();

        // check that the RefundRegisteredEvent receipt is populated correctly
        assert_eq!(refund_registered_event[0].amount, Bits256(*dust_addr));
        assert_eq!(
            refund_registered_event[0].asset.value,
            Bits256(*l1_token_address)
        );
        assert_eq!(
            refund_registered_event[0].from.value,
            Bits256(*from_address)
        );

        // verify that no tokeens were minted for message.data.to
        let balance = recipient_wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;
        assert_eq!(balance, 0);
        Ok(())
    }

    #[tokio::test]
    async fn depositing_amount_too_large_registers_refund() -> Result<(), Error> {
        let (_, _, _root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;
        let mut recipient_wallet = WalletUnlocked::new_random(None);

        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut env::decode_hex(FROM));
        message_data.append(&mut recipient_wallet.address().hash().to_vec());
        message_data.append(&mut env::decode_hex(OVERFLOWING_AMOUNT));

        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(vec![coin], vec![message], None).await;

        recipient_wallet.set_provider(provider);

        let variable_output = Output::Variable {
            amount: 0,
            to: Address::zeroed(),
            asset_id: AssetId::default(),
        };
        let message_output = Output::Message {
            recipient: Address::zeroed(),
            amount: 0,
        };

        // Relay the test message to the test contract
        let receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &vec![variable_output, message_output],
        )
        .await;

        let refund_registered_event = test_contract
            .logs_with_type::<utils::environment::bridgefungibletokencontract_mod::RefundRegisteredEvent>(
            &receipts,
        )?;

        let provider = wallet.get_provider().unwrap();
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();

        let dust_addr: Address = Address::from_str(&OVERFLOWING_AMOUNT).unwrap();
        let l1_token_address: Address = Address::from_str(&L1_TOKEN).unwrap();
        let from_address: Address = Address::from_str(&FROM).unwrap();

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_balance, 100);

        // check that the RefundRegisteredEvent receipt is populated correctly
        assert_eq!(refund_registered_event[0].amount, Bits256(*dust_addr));
        assert_eq!(
            refund_registered_event[0].asset.value,
            Bits256(*l1_token_address)
        );
        assert_eq!(
            refund_registered_event[0].from.value,
            Bits256(*from_address)
        );

        // verify that no tokeens were minted for message.data.to
        let balance = recipient_wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;
        assert_eq!(balance, 0);
        Ok(())
    }

    #[tokio::test]
    async fn can_get_name() {
        let wallet = launch_provider_and_get_wallet().await;
        // Set up the environment
        let (contract, _id) = env::get_fungible_token_instance(wallet.clone()).await;

        let call_response = contract.methods().name().call().await.unwrap();
        assert_eq!(call_response.value, "MY_TOKEN")
    }

    #[tokio::test]
    async fn can_get_symbol() {
        let wallet = launch_provider_and_get_wallet().await;
        // Set up the environment
        let (contract, _id) = env::get_fungible_token_instance(wallet.clone()).await;

        let call_response = contract.methods().symbol().call().await.unwrap();
        assert_eq!(call_response.value, "MYTKN")
    }

    #[tokio::test]
    async fn can_get_decimals() {
        let wallet = launch_provider_and_get_wallet().await;
        // Set up the environment
        let (contract, _id) = env::get_fungible_token_instance(wallet.clone()).await;

        let call_response = contract.methods().decimals().call().await.unwrap();
        assert_eq!(call_response.value, 9)
    }

    #[tokio::test]
    async fn can_get_layer1_token() {
        let wallet = launch_provider_and_get_wallet().await;
        // Set up the environment
        let (contract, _id) = env::get_fungible_token_instance(wallet.clone()).await;
        let l1_token = Address::from_str(&L1_TOKEN).unwrap();

        let call_response = contract.methods().layer1_token().call().await.unwrap();
        assert_eq!(call_response.value, Bits256(*l1_token))
    }

    #[tokio::test]
    async fn can_get_layer1_decimals() {
        let wallet = launch_provider_and_get_wallet().await;
        // Set up the environment
        let (contract, _id) = env::get_fungible_token_instance(wallet.clone()).await;

        let call_response = contract.methods().layer1_decimals().call().await.unwrap();
        assert_eq!(call_response.value, 18)
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
        message_data.append(&mut env::decode_hex(MINIMUM_BRIDGABLE_AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            _test_contract_id,
            _provider,
        ) = env::setup_environment(vec![coin], vec![message], None).await;

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
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    #[ignore]
    async fn verification_fails_with_wrong_predicate_root() {
        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        let wrong_predicate_root =
            "0x1111110000000000000000000000000000000000000000000000000000111111";
        // append incorrect predicate root to data:
        message_data.append(&mut env::decode_hex(wrong_predicate_root));
        message_data.append(&mut env::decode_hex(TO));
        message_data.append(&mut env::decode_hex(MINIMUM_BRIDGABLE_AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            _test_contract_id,
            _provider,
        ) = env::setup_environment(vec![coin], vec![message], None).await;

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
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_sender() {
        let (_, _, root_array) = utils::ext_sdk_provider::get_contract_message_predicate().await;
        let mut message_data = Vec::with_capacity(5);
        // append incorrect L1 token to data:
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut root_array.to_vec());
        message_data.append(&mut env::decode_hex(TO));
        message_data.append(&mut env::decode_hex(MINIMUM_BRIDGABLE_AMOUNT));
        let message_data = env::prefix_contract_id(message_data).await;
        let message = (100, message_data);
        let coin = (DEFAULT_COIN_AMOUNT, AssetId::default());

        let bad_sender: &str =
            "0x55555500000000000000000000000000000000000000000000000000005555555";

        // Set up the environment
        let (
            wallet,
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            _test_contract_id,
            _provider,
        ) = env::setup_environment(vec![coin], vec![message], Some(bad_sender)).await;

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
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        // assert_eq!(test_contract_balance, 100);
    }
}
