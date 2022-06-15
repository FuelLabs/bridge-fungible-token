use fuels::{prelude::*};
use fuel_core::service::{Config, FuelService};
use fuel_gql_client::client::FuelClient;
use fuel_gql_client::fuel_tx::{Transaction, Receipt, Bytes32};
use fuels_contract::script::Script;
use fuel_crypto::Hasher;



pub async fn run_compiled_script(binary_filepath: &str) -> Result<Vec<Receipt>, Error> {
    let script_binary = std::fs::read(binary_filepath)?;
    let server = FuelService::new_node(Config::local_node()).await.unwrap();
    let client = FuelClient::from(server.bound_address);

    let tx = Transaction::Script {
        gas_price: 0,
        gas_limit: 1000000,
        maturity: 0,
        byte_price: 0,
        receipts_root: Default::default(),
        script: script_binary, // Pass the compiled script into the tx
        script_data: vec![],
        inputs: vec![],
        outputs: vec![],
        witnesses: vec![vec![].into()],
        metadata: None,
    };

    let script = Script::new(tx);
    script.call(&client).await
}


#[tokio::test]
async fn test_run_compiled_script() {

    let path_to_bin = "../temp/out/debug/temp.bin";

    // Calculate padded script hash
    let mut script_bytecode = std::fs::read(path_to_bin).unwrap().to_vec();
    // VM will read (and hash) script bytecode in whole words, so pad to the next word.
    let padding = script_bytecode.len() % 8;
    script_bytecode.append(&mut vec![0; padding]);
    let script_hash = Hasher::hash(&script_bytecode); // This is the hard that must be hard-coded in the predicate

    // Run script and get the hash it returns
    let return_val = run_compiled_script(path_to_bin).await.unwrap();
    let script_hash_from_vm = unsafe{Bytes32::from_slice_unchecked(return_val[0].data().unwrap())};

    assert_eq!(script_hash_from_vm, script_hash);

}
