use fuels::prelude::*;
use fuels::test_helpers::Config;
use fuel_crypto::Hasher;
use fuel_gql_client::fuel_tx::{AssetId, Contract, Input, Output, Transaction, UtxoId};
use fuels_contract::script::Script;

// Predicate testing:

// 0.1 Write a script that sends coin to an address
// 0.2 Write a predicate that expects this script hash
// 1. send some coins to the predicate root
// 2. Build script transaction that spends Coin input, providing predicate along with input
// 3. Check that coins were spent

async fn get_balance(provider: &Provider, address: Address, asset: AssetId) -> u64 {
    let balance = provider
        .get_asset_balance(&address, asset)
        .await
        .unwrap();
    balance
}

#[tokio::test]
async fn predicate_spend() {
    // Set up a wallet and send some native asset to the predicate root
    let native_asset: AssetId = Default::default();
    let mut provider_config = Config::local_node();
    provider_config.predicates = true; // predicates are currently disabled by default
    let wallet = launch_custom_provider_and_get_single_wallet(Some(provider_config)).await;

    // When `launch_custom_provider_and_get_wallets` lands, use this to test with other assets
    //let wallets_config = WalletsConfig::new(Some(1), Some(2), Some(10000));
    //let wallet = launch_custom_provider_and_get_wallets(wallets_config, provider_config).await;

    // Get provider and client
    let provider = wallet.get_provider().unwrap();
    let client = &provider.client;

    // This is to produce the padded script hash which must be hard-coded in the predicate,
    // In order to constrain its spending transaction to be exactly this script
    let mut script_bytecode = std::fs::read("../script/out/debug/script.bin").unwrap().to_vec();
    let padding = script_bytecode.len() % 8;
    let script_bytecode_unpadded = script_bytecode.clone();
    script_bytecode.append(&mut vec![0; padding]);
    let script_hash = Hasher::hash(&script_bytecode);

    println!("Padded script length: {}", script_bytecode.len());
    println!("Padded script hash   : 0x{:?}", script_hash);

    // Get predicate bytecode and root
    let predicate_bytecode = std::fs::read("../predicate/out/debug/predicate.bin").unwrap();
    let predicate_root: [u8; 32] = (*Contract::root_from_code(&predicate_bytecode)).into();
    let predicate_root = Address::from(predicate_root);

    // Transfer some coins to the predicate root
    let _receipt = wallet.transfer(
        &predicate_root,
        1000,
        native_asset,
        TxParameters::default()
    ).await.unwrap();



    let mut predicate_balance = get_balance(&provider, predicate_root, native_asset).await;
    println!("Predicate root balance before: {}", predicate_balance);

    // Use default address as receiver - see script
    let receiver_address = Address::new([1u8; 32]);
    let mut receiver_balance = get_balance(&provider, receiver_address, native_asset).await;
    println!("Receiver balance before: {}", receiver_balance);

    assert_eq!(predicate_balance, 1000);
    assert_eq!(receiver_balance, 0);

    // Get predicate coin to spend
    let predicate_coin = &provider
        .get_coins(&predicate_root)
        .await
        .unwrap()[0];

    let predicate_coin_utxo_id = UtxoId::from(predicate_coin.utxo_id.clone());

    // Configure inputs and outputs to send coins from predicate to another wallet.

    // This is the coin belonging to the predicate root
    let input_predicate = Input::CoinPredicate {
        utxo_id: predicate_coin_utxo_id,
        owner: predicate_root,
        amount: 1000,
        asset_id: native_asset,
        maturity: 0,
        predicate: predicate_bytecode,
        predicate_data: vec![],
    };

    // A variable output for the coin transfer
    let output_variable = Output::Variable {
        to: receiver_address,
        amount: 0,
        asset_id: AssetId::default(),
    };

    // A variable output for change (Does this need to be explicitly a Change output?)
    let output_change = Output::Variable {
        to: Address::default(),
        amount: 0,
        asset_id: AssetId::default(),
    };


    let tx = Transaction::Script {
        gas_price: 0,
        gas_limit: 10_000_000,
        maturity: 0,
        byte_price: 0,
        receipts_root: Default::default(),
        script: script_bytecode_unpadded,
        script_data: vec![],
        inputs: vec![input_predicate],
        outputs: vec![output_variable, output_change],
        witnesses: vec![],
        metadata: None,
    };

    let script = Script::new(tx);

    let _receipts = script.call(&client).await.unwrap();

    predicate_balance = get_balance(&provider, predicate_root, native_asset).await;
    println!("Predicate root balance after: {}", predicate_balance);

    receiver_balance = get_balance(&provider, receiver_address, native_asset).await;
    println!("Receiver balance after: {}", receiver_balance);

    assert_eq!(predicate_balance, 0);
    assert_eq!(receiver_balance, 1000);

}
