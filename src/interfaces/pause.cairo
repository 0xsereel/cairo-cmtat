// SPDX-License-Identifier: MPL-2.0
// ERC-3643 pause and ERC-8343 contract deactivation.

/// SNIP-5 id of `IERC8343`: XOR of the extended selectors of
/// `deactivate_contract()` and `deactivated()->E((),())` (SNIP-5 encoding:
/// short type names, `bool` as `E((),())`).
pub const IERC8343_ID: felt252 = 0xb0170a1ae08515ecaede32d780ec7e7d7dc84266f5e007cf6411db91ff8b;

#[starknet::interface]
pub trait IERC3643Pause<TState> {
    fn pause(ref self: TState);
    fn unpause(ref self: TState);
    fn paused(self: @TState) -> bool;
}

#[starknet::interface]
pub trait IERC8343<TState> {
    fn deactivate_contract(ref self: TState);
    fn deactivated(self: @TState) -> bool;
}
