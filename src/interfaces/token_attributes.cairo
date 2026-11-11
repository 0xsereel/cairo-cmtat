// SPDX-License-Identifier: MPL-2.0
// ERC-3643 mutable token attributes and version.

#[starknet::interface]
pub trait IERC3643ERC20Base<TState> {
    fn set_name(ref self: TState, name: ByteArray);
    fn set_symbol(ref self: TState, symbol: ByteArray);
}

#[starknet::interface]
pub trait IERC3643Version<TState> {
    fn version(self: @TState) -> ByteArray;
}
