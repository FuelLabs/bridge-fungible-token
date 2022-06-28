predicate;

use std::assert::assert;
use std::hash::*;
use std::tx::*;


/// Get the script spending the input belonging to this predicate hash
fn get_script_bytecode<T>() -> T {
    let script_ptr = tx_script_start_offset();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {

    // The hash of the (padded) script which must spend the input belonging to this predicate
    let SPENDING_SCRIPT_HASH = 0xfb3d71fb940415add9614ec416e0d20b7a9eabbcbac08d833814de253a664406;

    // Verify script bytecode hash is expected
    let script: [u64; 67] = get_script_bytecode(); // Note : 8 * 67 = 536, which is 4 bytes longer than the script. Need to pad script by 4 bytes before hashing for SPENDING_SCRIPT_HASH
    let script_hash = sha256(script);

    script_hash == SPENDING_SCRIPT_HASH
}
