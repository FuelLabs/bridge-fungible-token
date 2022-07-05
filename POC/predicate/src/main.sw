predicate;

use std::assert::assert;
use std::hash::*;
use std::tx::tx_script_bytecode;


/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {

    // The hash of the (padded) script which must spend the input belonging to this predicate
    let SPENDING_SCRIPT_HASH = 0x0c8f5cc09ed6f22c766be1e0412d33841405cdbf8dae3680d15fb353027db87d;

    // Verify script bytecode hash is expected
    let script_bytcode: [u64; 101] = tx_script_bytecode(); // Note : 8 * 101 = 808, which is 4 bytes longer than the script. Need to pad script by 4 bytes before hashing for SPENDING_SCRIPT_HASH
    sha256(script_bytcode) == SPENDING_SCRIPT_HASH
}
