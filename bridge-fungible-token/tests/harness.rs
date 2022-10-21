mod utils {
    pub mod environment;
    pub mod ext_sdk_provider;
}

use std::str::FromStr;
use utils::environment as env;
use utils::ext_sdk_provider;

use fuels::prelude::*;
use fuels::tx::{Address, AssetId};

pub const L1_TOKEN: &str = "0x00000000000000000000000000000000000000000000000000000000deadbeef";
pub const TO: &str = "0x0000000000000000000000000000000000000000000000000000000000000777";
pub const FROM: &str = "0x0000000000000000000000008888888888888888888888888888888888888888";
pub const MINIMUM_BRIDGABLE_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000000000000003B9ACA00";
pub const DUST: &str = "0x000000000000000000000000000000000000000000000000000000003B9AC9FF";
pub const MAXIMUM_BRIDGABLE_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000000FFFFFFFFD5B51A00";
pub const OVERFLOWING_AMOUNT: &str =
    "0x000000000000000000000000000000000000000000000001FFFFFFFFD5B51A00";

mod success {
    use super::*;

    #[tokio::test]
    async fn relay_message_with_predicate_and_script_constraint() -> Result<(), Error> {
        let mut wallet = env::setup_wallet();

        let (message, coin) = env::contruct_msg_data(
            L1_TOKEN,
            FROM,
            wallet.address().hash().to_vec(),
            MINIMUM_BRIDGABLE_AMOUNT,
        )
        .await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        let test_contract_base_asset_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();

        let balance = wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_base_asset_balance, 100);
        // Check that wallet now has bridged coins
        assert_eq!(balance, 1);
        Ok(())
    }

    #[tokio::test]
    async fn depositing_max_amount_ok() -> Result<(), Error> {
        let mut wallet = env::setup_wallet();

        let (message, coin) = env::contruct_msg_data(
            L1_TOKEN,
            FROM,
            wallet.address().hash().to_vec(),
            MAXIMUM_BRIDGABLE_AMOUNT,
        )
        .await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        let test_contract_base_asset_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();

        let balance = wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_base_asset_balance, 100);
        // Check that wallet now has bridged coins
        assert_eq!(balance, 18446744073);
        Ok(())
    }

    #[tokio::test]
    #[ignore]
    async fn claim_refund() {
        // perform failing deposit first to register a refund, verify, then claim and verify L2 balances changed as expected. L1 nweeds to be checked as well in integration tests
    }

    #[tokio::test]
    async fn withdraw_from_bridge() -> Result<(), Error> {
        // perform successful deposit first, verify it, then withdraw and verify balances
        let mut wallet = env::setup_wallet();

        let (message, coin) = env::contruct_msg_data(
            L1_TOKEN,
            FROM,
            wallet.address().hash().to_vec(),
            MAXIMUM_BRIDGABLE_AMOUNT,
        )
        .await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        let test_contract_base_asset_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();

        let balance = wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_base_asset_balance, 100);
        // Check that wallet now has bridged coins
        assert_eq!(balance, 18446744073);

        // Now try to withdraw
        let call_params = CallParameters::new(
            Some(3000),
            Some(AssetId::new(*test_contract_id.hash())),
            Some(1_000_000),
        );

        let call_response = test_contract
            .methods()
            .withdraw_to(Bits256(*wallet.address().hash()))
            .call_params(call_params)
            .append_message_outputs(1)
            .call()
            .await
            .unwrap();

        println!("Receipts: {:#?}", call_response.receipts);

        Ok(())
    }

    #[tokio::test]
    async fn depositing_dust_registers_refund() -> Result<(), Error> {
        // "dust" here refers to any amount less than 1_000_000_000.
        // This is to account for conversion between the 18 decimals on most erc20 contracts, and the 9 decimals in the Fuel BridgeFungibleToken contract

        let mut wallet = env::setup_wallet();

        let (message, coin) =
            env::contruct_msg_data(L1_TOKEN, FROM, wallet.address().hash().to_vec(), DUST).await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        let refund_registered_event = test_contract
            .logs_with_type::<utils::environment::bridgefungibletokencontract_mod::RefundRegisteredEvent>(
            &receipts,
        )?;

        // Verify the message value was received by the test contract
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        let balance = wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        assert_eq!(test_contract_balance, 100);
        assert_eq!(
            refund_registered_event[0].amount,
            Bits256(*Address::from_str(&DUST).unwrap())
        );
        assert_eq!(
            refund_registered_event[0].asset.value,
            Bits256(*Address::from_str(&L1_TOKEN).unwrap())
        );
        assert_eq!(
            refund_registered_event[0].from.value,
            Bits256(*Address::from_str(&FROM).unwrap())
        );

        // verify that no tokens were minted for message.data.to
        assert_eq!(balance, 0);
        Ok(())
    }

    #[tokio::test]
    async fn depositing_amount_too_large_registers_refund() -> Result<(), Error> {
        let mut wallet = env::setup_wallet();

        let (message, coin) = env::contruct_msg_data(
            L1_TOKEN,
            FROM,
            wallet.address().hash().to_vec(),
            OVERFLOWING_AMOUNT,
        )
        .await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        let refund_registered_event = test_contract
            .logs_with_type::<utils::environment::bridgefungibletokencontract_mod::RefundRegisteredEvent>(
            &receipts,
        )?;

        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        let balance = wallet
            .get_asset_balance(&AssetId::new(*test_contract_id.hash()))
            .await?;

        // Verify the message value was received by the test contract
        assert_eq!(test_contract_balance, 100);

        // check that the RefundRegisteredEvent receipt is populated correctly
        assert_eq!(
            refund_registered_event[0].amount,
            Bits256(*Address::from_str(&OVERFLOWING_AMOUNT).unwrap())
        );
        assert_eq!(
            refund_registered_event[0].asset.value,
            Bits256(*Address::from_str(&L1_TOKEN).unwrap())
        );
        assert_eq!(
            refund_registered_event[0].from.value,
            Bits256(*Address::from_str(&FROM).unwrap())
        );

        // verify that no tokens were minted for message.data.to
        assert_eq!(balance, 0);
        Ok(())
    }

    #[tokio::test]
    async fn can_get_name() {
        // @review reuse let wallet = env::setup_wallet(); ?
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
    #[ignore]
    async fn fails_to_withdraw_too_much_from_bridge() {}

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_l1_token() {
        let mut wallet = env::setup_wallet();
        let wrong_token_value: &str =
            "0x1111110000000000000000000000000000000000000000000000000000111111";

        let (message, coin) = env::contruct_msg_data(
            wrong_token_value,
            FROM,
            env::decode_hex(TO),
            MINIMUM_BRIDGABLE_AMOUNT,
        )
        .await;

        // Set up the environment
        let (
            test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            _test_contract_id,
            provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], None).await;

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;

        // Verify the message value was received by the test contract
        let test_contract_balance = provider
            .get_contract_asset_balance(test_contract.get_contract_id(), AssetId::default())
            .await
            .unwrap();
        assert_eq!(test_contract_balance, 100);
    }

    #[tokio::test]
    #[should_panic(expected = "Revert(42)")]
    async fn verification_fails_with_wrong_sender() {
        let mut wallet = env::setup_wallet();
        let (message, coin) = env::contruct_msg_data(
            L1_TOKEN,
            FROM,
            env::decode_hex(TO),
            MINIMUM_BRIDGABLE_AMOUNT,
        )
        .await;

        let bad_sender: &str =
            "0x55555500000000000000000000000000000000000000000000000000005555555";

        // Set up the environment
        let (
            _test_contract,
            contract_input,
            coin_inputs,
            message_inputs,
            _test_contract_id,
            _provider,
        ) = env::setup_environment(&mut wallet, vec![coin], vec![message], Some(bad_sender)).await;

        // Relay the test message to the test contract
        let _receipts = env::relay_message_to_contract(
            &wallet,
            message_inputs[0].clone(),
            contract_input,
            &coin_inputs[..],
            &vec![],
            &env::generate_outputs(),
        )
        .await;
    }
}
