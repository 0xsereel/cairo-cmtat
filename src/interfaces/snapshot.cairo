// SPDX-License-Identifier: MPL-2.0
// SnapshotEngine interfaces. Production SnapshotEngines live outside this
// repository; `src/mocks` has a recorder for tests.

use starknet::ContractAddress;

/// Implemented by the SnapshotEngine. Called after every balance change with the
/// balances and total supply from before the change.
#[starknet::interface]
pub trait ISnapshotEngine<TState> {
    fn operate_on_transfer(
        ref self: TState,
        from: ContractAddress,
        to: ContractAddress,
        balance_from: u256,
        balance_to: u256,
        total_supply: u256,
    );
}

/// Implemented by the token.
#[starknet::interface]
pub trait ISnapshotEngineModule<TState> {
    fn snapshot_engine(self: @TState) -> ContractAddress;
    /// Requires SNAPSHOOTER_ROLE. The zero address removes the engine.
    fn set_snapshot_engine(ref self: TState, snapshot_engine: ContractAddress);
}
