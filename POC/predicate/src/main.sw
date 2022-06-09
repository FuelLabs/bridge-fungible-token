predicate;

use std::assert::assert;
use std::hash::*;


/// Get the script spending the input belonging to this predicate hash. TO DO : replace with std-lib version when ready
fn get_script<T>() -> T {
    let script_ptr = std::context::registers::instrs_start();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

/// Predicate verifying a message input is being spent according to the rules for a valid deposit
fn main() -> bool {

    // The hash of the script which must spend the input belonging to this predicate
    const SPENDING_SCRIPT_HASH = 0x6ad217d74e5bedfa3d9162c47c3933f9f9379af5510a6d8122f157f2216cc806;


    // Verify script bytecode hash is expected
    let script: [byte;
    524] = get_script(); // Note : Make sure 524 equal to actual compiled script length
    let script_hash = sha256(script);
    assert(script_hash == SPENDING_SCRIPT_HASH);

    true
}
