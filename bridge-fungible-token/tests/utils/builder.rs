/**
 * TODO: This module contains functions that should eventually
 * be made part of the fuels-rs sdk repo as part of the Provider
 * implementation, similar to functions like 'build_transfer_tx'
 */
use fuels::signers::fuel_crypto::Hasher;

use fuels::prelude::*;
use fuels::tx::{AssetId, Bytes32, Input, Output, Transaction};

const CONTRACT_MESSAGE_MIN_GAS: u64 = 30_000_000;
const CONTRACT_MESSAGE_SCRIPT_BINARY: &str =
    "../bridge-message-predicates/contract_message_script.bin";

/// Gets the message to contract script
pub async fn get_contract_message_script() -> (Vec<u8>, Bytes32) {
    let script_bytecode = std::fs::read(CONTRACT_MESSAGE_SCRIPT_BINARY).unwrap();
    let script_hash = Hasher::hash(&script_bytecode.clone());
    (script_bytecode, script_hash)
}

/// Build a message-to-contract transaction with the given input coins and outputs
/// note: unspent gas is returned to the owner of the first given gas input
pub async fn build_contract_message_tx(
    message: Input,
    contracts: Vec<Input>,
    gas_coins: &[Input],
    params: TxParameters,
) -> ScriptTransaction {
    // Get the script and predicate for contract messages
    let (script_bytecode, _) = get_contract_message_script().await;
    let length = contracts.len();

    // Start building tx list of inputs
    let mut tx_inputs: Vec<Input> = Vec::new();
    tx_inputs.push(message);
    for contract in contracts {
        tx_inputs.push(contract);
    }

    // Start building tx list of outputs
    let mut tx_outputs: Vec<Output> = Vec::new();
    tx_outputs.push(Output::Contract {
        input_index: 1u8,
        balance_root: Bytes32::zeroed(),
        state_root: Bytes32::zeroed(),
    });

    // If there are more than 1 contract inputs, it means this is a deposit to contract.
    if length > 1usize {
        tx_outputs.push(Output::Contract {
            input_index: 2u8,
            balance_root: Bytes32::zeroed(),
            state_root: Bytes32::zeroed(),
        })
    };

    // Build a change output for the owner of the first provided coin input
    if !gas_coins.is_empty() {
        let coin: &Input = &gas_coins[0];
        match coin {
            Input::CoinSigned { owner, .. } | Input::CoinPredicate { owner, .. } => {
                // Add change output
                tx_outputs.push(Output::Change {
                    to: owner.clone(),
                    amount: 0,
                    asset_id: AssetId::default(),
                });
            }
            _ => {
                // do nothing
            }
        }
    }

    // Append provided inputs and outputs
    tx_inputs.append(&mut gas_coins.to_vec());

    // Create a new transaction
    Transaction::script(
        params.gas_price(),
        CONTRACT_MESSAGE_MIN_GAS * 10,
        params.maturity(),
        script_bytecode,
        vec![],
        tx_inputs,
        tx_outputs,
        vec![],
    )
    .into()
}
