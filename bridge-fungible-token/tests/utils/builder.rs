use fuel_core_types::fuel_tx::{input::Input, Bytes32, Output, Transaction};
/**
 * TODO: This module contains functions that should eventually
 * be made part of the fuels-rs sdk repo as part of the Provider
 * implementation, similar to functions like 'build_transfer_tx'
 */
use fuels::{accounts::fuel_crypto::Hasher, prelude::*};

const CONTRACT_MESSAGE_MIN_GAS: u64 = 30_000_000;
const CONTRACT_MESSAGE_SCRIPT_BINARY: &str =
    "../bridge-message-predicates/contract_message_script.bin";

/// Gets the message to contract script
pub async fn get_contract_message_script() -> (Vec<u8>, Bytes32) {
    let script_bytecode = std::fs::read(CONTRACT_MESSAGE_SCRIPT_BINARY).unwrap();
    // TODO: remove script_hash? Seems unused
    let script_hash = Hasher::hash(script_bytecode.clone());
    (script_bytecode, script_hash)
}

/// Build a message-to-contract transaction with the given input coins and outputs
/// note: unspent gas is returned to the owner of the first given gas input
pub async fn build_contract_message_tx(
    message: Input,
    contracts: Vec<Input>,
    gas_coins: &[Input],
    optional_outputs: &[Output],
    params: TxParameters,
) -> ScriptTransaction {
    // Get the script and predicate for contract messages
    let (script_bytecode, _) = get_contract_message_script().await;
    let number_of_contracts = contracts.len();
    let mut tx_inputs: Vec<Input> = Vec::with_capacity(1 + number_of_contracts + gas_coins.len());
    let mut tx_outputs: Vec<Output> = Vec::new();

    // Start building tx list of inputs
    tx_inputs.push(message);
    for contract in contracts {
        tx_inputs.push(contract);
    }

    // Start building tx list of outputs
    tx_outputs.push(Output::Contract {
        input_index: 1u8,
        balance_root: Bytes32::zeroed(),
        state_root: Bytes32::zeroed(),
    });

    // If there is more than 1 contract input, it means this is a deposit to contract.
    if number_of_contracts > 1usize {
        tx_outputs.push(Output::Contract {
            input_index: 2u8,
            balance_root: Bytes32::zeroed(),
            state_root: Bytes32::zeroed(),
        })
    };

    // Build a change output for the owner of the first provided coin input
    if !gas_coins.is_empty() {
        match gas_coins[0].clone() {
            Input::CoinSigned(coin) => {
                tx_outputs.push(Output::Change {
                    to: coin.owner,
                    amount: 0,
                    asset_id: AssetId::default(),
                });
            }
            Input::CoinPredicate(predicate) => {
                tx_outputs.push(Output::Change {
                    to: predicate.owner,
                    amount: 0,
                    asset_id: AssetId::default(),
                });
            }
            _ => {
                // do nothing
            }
        }

        // Append provided inputs
        tx_inputs.append(&mut gas_coins.to_vec());
    }

    // Append provided outputs
    tx_outputs.append(&mut optional_outputs.to_vec());

    // Create a new transaction
    Transaction::script(
        params.gas_price(),
        CONTRACT_MESSAGE_MIN_GAS * 10,
        params.maturity().into(),
        script_bytecode,
        vec![],
        tx_inputs,
        tx_outputs,
        vec![],
    )
    .into()
}
