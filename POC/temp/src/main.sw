script;

use std::hash::*;


/// Get the script spending the input belonging to this predicate hash
fn get_script_bytecode<T>() -> T {
    let script_ptr = std::context::registers::instrs_start();
    let script = asm(r1: script_ptr) {
        r1: T
    };
    script
}

fn main() -> b256 {

    // Add this to make the script not be a multiple of 8 bytes (e.g. 412 bytes => 51.5 words)
    let a = sha256(2);

    // length of array is script length padded to nearest full word
    let script: [u64; 52] = get_script_bytecode();
    sha256(script)
}
