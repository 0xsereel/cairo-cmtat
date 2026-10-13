// SPDX-License-Identifier: MPL-2.0
// CMTAT ERC20BaseModule extensions. The ERC-20 ABI itself uses OpenZeppelin's
// IERC20, IERC20Metadata and IERC20CamelOnly traits.

use starknet::ContractAddress;

#[starknet::interface]
pub trait IERC20BatchBalance<TState> {
    /// Returns the balance of each address and the total supply.
    fn batch_balance_of(self: @TState, addresses: Span<ContractAddress>) -> (Array<u256>, u256);
}
