predicate;

use std::assert::assert;
use std::hash::*;
use std::tx::tx_script_bytecode;


/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {

    // The hash of the (padded) script which must spend the input belonging to this predicate
    let SPENDING_SCRIPT_HASH = 0x0f64699ad97a254a7fca28364e2b5ec0156507cd7beb77fb25ff5133f8b6ad1a;

    // Verify script bytecode hash is expected
    let script_bytcode: [u64; 102] = tx_script_bytecode(); // Note : 8 * 101 = 808, which is 4 bytes longer than the script. Need to pad script by 4 bytes before hashing for SPENDING_SCRIPT_HASH
    sha256(script_bytcode) == SPENDING_SCRIPT_HASH
}
