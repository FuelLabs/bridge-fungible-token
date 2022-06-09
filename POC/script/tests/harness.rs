use fuels::{prelude::*, tx::ContractId};
use fuels_abigen_macro::abigen;

use fuel_core::service::{Config, FuelService};
use fuel_gql_client::client::FuelClient;
use fuel_gql_client::fuel_tx::{Receipt, Transaction, AssetId};
use fuels_contract::script::Script;
use fuel_crypto::Hasher;
use fuels_signers::provider::Provider;


#[tokio::test]
async fn run_script() {

    let server = FuelService::new_node(Config::local_node()).await.unwrap();
    let client = FuelClient::from(server.bound_address);

    let script_binary = std::fs::read("../script/out/debug/script.bin").unwrap();
    let script_hash = Hasher::hash(&script_binary);
    println!("Script hash   : 0x{}", script_hash);

    let predicate_binary = std::fs::read("../predicate/out/debug/predicate.bin").unwrap();
    let predicate_hash = Hasher::hash(predicate_binary);
    let predicate_hash_as_address = fuels::tx::Address::from(*predicate_hash);
    println!("Predicate hash: 0x{}", predicate_hash);

    // Set up a wallet and send some native asset to the predicate hash
    let native_asset: AssetId = Default::default();
    let wallet = launch_provider_and_get_single_wallet().await;
    let wallet_balance = wallet.get_asset_balance(&native_asset).await.unwrap();
    println!("Wallet balance: {}", wallet_balance);
    let receipt = wallet.transfer(&predicate_hash_as_address, 1000, native_asset, TxParameters::default()).await.unwrap();

    // Inspect predicate balance
    let provider = wallet.get_provider().unwrap();
    let predicate_balance = provider.get_asset_balance(&predicate_hash_as_address, native_asset).await.unwrap();
    println!("Predicate balance: {}", predicate_balance);


    // Need to configure inputs and outputs to send coins from predicate to another wallet. 
    // Coin input will have a predicate attached


    let tx = Transaction::Script {
        gas_price: 0,
        gas_limit: 10_000_000,
        maturity: 0,
        byte_price: 0,
        receipts_root: Default::default(),
        script: script_binary, // Here we pass the compiled script into the transaction
        script_data: vec![],
        inputs: vec![],
        outputs: vec![],
        witnesses: vec![vec![].into()],
        metadata: None,
    };

    let script = Script::new(tx);

    //let receipts = script.call(&client).await.unwrap();
}


// Predicate testing:

// 0.1 Write a script that sends coin to an address, and compile. Get script hash
// 0.2 Write a predicate that expects this script hash. Get predicate hash
// 1. send some coins to the predicate hash 
// 2. Build corresponding script transaction that spends Coin input, provide predicate along with input (what about witness?)

