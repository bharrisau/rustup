#[no_std];

use core::vec::Vec;

#[path = "../lib/core/core/mod.rs"]
mod core;

#[start]
#[no_mangle]
pub extern "C" fn _start() {
    let mut xs = Vec::new();
    let mut i = 0;
    while i < 100 {
        xs.push(i);
        i += 1;
    }
}

#[no_mangle]
pub extern "C" fn _exit() {
  while true {

  }
}