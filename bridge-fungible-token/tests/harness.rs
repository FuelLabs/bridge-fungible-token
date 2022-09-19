mod utils {
    pub mod environment;
    pub mod ext_fuel_core;
    pub mod ext_sdk_provider;
}
use std::str::FromStr;

use utils::environment as env;
use utils::ext_fuel_core;
use utils::ext_sdk_provider;

use fuels::test_helpers::DEFAULT_COIN_AMOUNT;
use fuels::tx::{Address, AssetId, Bytes32, ContractId, Output};

// pub const RANDOM_SALT: &str = "0x1a896ebd5f55c10bc830755278e6d2b9278b4177b8bca400d3e7710eee293786";

pub const L1_TOKEN: &str = "0xabcdef0000000000000000000000000000000000000000000000000000abcdef";
pub const TO: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const AMOUNT: &str = "0x0000000000000000000000000000000000000000000000000000000000000000";
pub const PREDICATE_ROOT: &str =
    "0xbc5869a28f97b24944a0aa9724d8001427f7a594fe9fd739a1d6b27c02c47f7f";

mod success {
    use super::*;

    #[tokio::test]
    async fn relay_message_with_predicate_and_script_constraint() {
        // TODO: figure out how to use the value of the returned `root` instead of the const PREDICATE_ROOT
        let (_, _root) = utils::ext_sdk_provider::get_contract_message_predicate().await;

        let mut message_data = Vec::with_capacity(5);
        message_data.append(&mut env::decode_hex(L1_TOKEN));
        message_data.append(&mut env::decode_hex(PREDICATE_ROOT));
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
    // TODO: come up with a simple way to modify the test Message, altering fields to cause specific reverts. perhaps passing in 2 more args to setup_environment() as Options. None() means use the existing hardcoded values, Some(v) means use the passed-in args
}
