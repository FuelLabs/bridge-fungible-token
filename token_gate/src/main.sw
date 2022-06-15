contract;

use std::{
    address::Address,
    assert::require,
    chain::auth::{AuthError, Sender, msg_sender},
    context::{call_frames::{contract_id, msg_asset_id}, msg_amount},
    contract_id::ContractId,
    indentity::Identity,
    logging::log,
    result::*,
    revert::revert,
    token::{mint_to_address, mint_to_contract, burn},
    vm::evm::evm_address::EvmAddress
};

////////////////////////////////////////
// Constants
////////////////////////////////////////

////////////////////////////////////////
// Storage declarations
////////////////////////////////////////

storage {
    // @todo decide if this should be an Identity. try to make the token general-purpose
    owner: ContractId,
    state: u64,
    refund_amounts: StorageMap<(b256, b256), u64>,
}

////////////////////////////////////////
// Helper functions
////////////////////////////////////////

    fn process_message() {
        // Finalize deposit
        // Verify first message input owner predicate == MessageToGatewayPredicate
        // Verify the msg sender is the L1ERC20Gateway contract
        // *predicate will have already verified only 1 message input
        // *predicate will have already verified this contract is supposed to receive mesage
        // * no value will be sent by the L1ERC20Gateway contract
    }

////////////////////////////////////////
// ABI definitions
////////////////////////////////////////

abi FungibleToken {
    fn constructor(owner: Identity);
    fn mint(to: Identity, amount: u64);
    fn burn(from: Identity, amount: u64);
    fn name() -> str[11];
    fn symbol() -> str[11];
    fn decimals() -> u8;
    fn layer1_token() -> EvmAddress;
    fn layer1_decimals() -> u8;
}

abi L2ERC20Gateway {
    fn withdraw_refund(originator: Identity);
    fn withdraw_to(to: Identity);
    fn finalize_deposit();
}

////////////////////////////////////////
// Errors
////////////////////////////////////////

enum FungibleTokenError {
    CannotReinitialize: (),
    StateNotInitialized: (),
    IncorrectAssetAmount: (),
    IncorrectAssetDeposited: (),
    UnauthorizedUser: (),
}

enum L2GatewayError {
    NoCoinsForwarded: (),
}

////////////////////////////////////////
// Events
////////////////////////////////////////

pub struct MintedEvent {
    to: Identity,
    amount: u64,
}

pub struct BurnedEvent {
    from: Identity,
    amount: u64,
}

struct Withdrawal {
    to: Identity,
    amount: u64,
    asset: ContractId,
}

////////////////////////////////////////
// ABI Implementations
////////////////////////////////////////

impl FungibleToken for Contract {
    fn constructor(owner: ContractId) {
        require(storage.state == 0, Error::CannotReinitialize);
        storage.owner = owner;
        storage.state = 1;
        true
    }

    // @todo decide if this needs to be public
    fn mint(to: Identity, amount: u64) {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        match sender.unwrap() {
            Sender::ContractId(address) => {
                require(storage.owner == address, Error::UnauthorizedUser);

                match to {
                    Sender::Address(address) => {
                        mint_to_address(amount, address);
                    },
                    Sender::ContractId(address) => {
                        mint_to_contract(amount, address);
                    }
                }
            },
            _ => revert(42),
        }

        log(MintedEvent {to, amount});
    }

    // @todo decide if this needs to be public
    fn burn(from: Identity, amount: u64) {
        require(storage.state == 1, Error::StateNotInitialized);

        let sender: Result<Sender, AuthError> = msg_sender();
        match sender.unwrap() {
            Sender::ContractId(address) => {
                require(storage.owner == address, Error::UnauthorizedUser);
                require(contract_id() == msg_asset_id(), Error::IncorrectAssetDeposited);
                require(amount == msg_amount(), Error::IncorrectAssetAmount);
                burn(amount);
            },
            _ => revert(42),
        }

        log(BurnedEvent {from, amount});
    }

    fn name() -> str[11] {
        "placeholder"
    }

    fn symbol() -> str[11] {
        "placeholder"
    }

    fn decimals() -> u8 {
        2
    }

    fn layer1_token() -> EvmAddress {
        ~EvmAddress::from(~b267::min())
    }

    fn layer1_decimals() -> u8 {
        2
    }
}

impl L2ERC20Gateway for Contract {
    fn withdraw_refund(originator: Identity) {}

    /// Withdraw coins back to L1 and burn the corresponding amount of coins
    /// on L2.
    ///
    /// # Arguments
    ///
    /// * `to` - the destination of the transfer (an Address or a ContractId)
    ///
    /// # Reverts
    ///
    /// * When no coins were sent with call
    fn withdraw_to(to: Identity) {
        // start withdrawal
        // Verify an amount of coins was sent with this transaction
        let withdrawal_amount = balance();
        require(withdrawal_amount != 0, L2GatewayError::NoCoinsForwarded);
        // Find what contract the coins originate from
        let origin_contract_id = msg_asset_id();
        // Verify this gateway can call to burn these coins
        // ???
        let token_contract = abi(FungibleToken, origin_contract_id);
        // Burn the coins sent (call `burn()` on L2 token contract)
        token_contract.burn{
            coins: withdrawal_amount,
            asset_id: origin_contract_id
        } (withdrawal_amount);

        // @todo implement me!
        // Output a message to release tokens locked on L1
        // send_message(...);
        log(withdrawal);
    }

    fn finalize_deposit() {}
}
