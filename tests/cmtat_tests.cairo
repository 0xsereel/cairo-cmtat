// SPDX-License-Identifier: MPL-2.0
// Test Suite for CMTAT Cairo Implementation

use starknet::{ContractAddress, contract_address_const};

// Test constants  
const ADMIN: felt252 = 0x123;
const USER1: felt252 = 0x456;

fn admin() -> ContractAddress { contract_address_const::<ADMIN>() }
fn user1() -> ContractAddress { contract_address_const::<USER1>() }

#[test]
fn test_basic_functionality() {
    // This is a basic test to verify the testing framework works
    let admin_addr = admin();
    assert(admin_addr != user1(), 'Admin should not equal user1');
}

#[test] 
fn test_simple_math() {
    let result = 2 + 2;
    assert(result == 4, 'Two plus two should equal four');
}