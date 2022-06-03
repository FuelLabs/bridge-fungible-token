script;

use gateway_abi::Gateway;

fn main() -> bool {
    // TO DO: hard-code the gateway's contractID when code is finalized
    let gateway_contract = abi(Gateway, 0x0000000000000000000000000000000000000000000000000000000000000000);
    let value = gateway_contract.processMessage();

    // TO DO: probably want to return whatever processMessage returns here
    true
}
