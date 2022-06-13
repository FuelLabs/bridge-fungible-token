use fuels::prelude::*;
use fuel_core::service::Config;
use fuel_crypto::Hasher;
use fuel_gql_client::fuel_tx::{AssetId, Input, Output, Transaction, UtxoId};
use fuels_contract::script::Script;

// Predicate testing:

// 0.1 Write a script that sends coin to an address, and compile. Get script hash
// 0.2 Write a predicate that expects this script hash. Get predicate hash
// 1. send some coins to the predicate hash
// 2. Build corresponding script transaction that spends Coin input, provide predicate along with input (what about witness?)

#[tokio::test]
async fn run_script() {
    // Set up a wallet and send some native asset to the predicate hash
    let native_asset: AssetId = Default::default();
    let mut config = Config::local_node();
    config.predicates = true;
    let wallet = launch_custom_provider_and_get_single_wallet(config).await;
    let wallet_balance = wallet.get_asset_balance(&native_asset).await.unwrap();
    println!("Wallet balance: {}", wallet_balance);

    // Get provider and client
    let provider = wallet.get_provider().unwrap();
    let client = &provider.client;

    // Get script binary and hash
    let script_binary = std::fs::read("../script/out/debug/script.bin").unwrap();
    let script_hash = Hasher::hash(&script_binary);
    println!("Script hash   : 0x{}", script_hash);

    // Get predicate binary and hash
    let predicate_binary = std::fs::read("../predicate/out/debug/predicate.bin").unwrap();
    let predicate_hash = Hasher::hash(predicate_binary.clone());
    let predicate_hash_as_address = fuels::tx::Address::from(*predicate_hash);
    println!("Predicate hash: 0x{}", predicate_hash);

    // Transfer some coins to the predicate hash
    let _receipt = wallet
        .transfer(
            &predicate_hash_as_address,
            1000,
            native_asset,
            TxParameters::default(),
        )
        .await
        .unwrap();

    // Inspect predicate hash balance
    let predicate_balance = provider
        .get_asset_balance(&predicate_hash_as_address, native_asset)
        .await
        .unwrap();
    println!("Predicate balance: {}", predicate_balance);

    // Get predicate coin to spend
    let predicate_coin: UtxoId = provider
        .get_coins(&predicate_hash_as_address)
        .await
        .unwrap()[0]
        .utxo_id
        .clone()
        .into();

    // Configure inputs and outputs to send coins from predicate to another wallet.

    // This is the coin belonging to the predicate hash
    let i1 = Input::CoinPredicate {
        utxo_id: predicate_coin,
        owner: predicate_hash_as_address,
        amount: 1000,
        asset_id: native_asset,
        maturity: 0,
        predicate: predicate_binary,
        predicate_data: vec![],
    };

    // A variable output for the coin transfer
    let o1 = Output::Variable {
        to: Address::zeroed(),
        amount: 0,
        asset_id: AssetId::default(),
    };

    let tx = Transaction::Script {
        gas_price: 0,
        gas_limit: 10_000_000,
        maturity: 0,
        byte_price: 0,
        receipts_root: Default::default(),
        script: script_binary, // Here we pass the compiled script into the transaction
        script_data: vec![],
        inputs: vec![i1],
        outputs: vec![o1, o1],
        witnesses: vec![vec![].into()],
        metadata: None,
    };

    let script = Script::new(tx);

    let _receipts = script.call(&client).await.unwrap();
}
