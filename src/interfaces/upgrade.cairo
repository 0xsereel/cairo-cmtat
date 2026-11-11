// SPDX-License-Identifier: MPL-2.0
// Storage version for upgrades, after OpenZeppelin's Solidity `Initializable`.

#[starknet::interface]
pub trait IUpgradeVersion<TState> {
    /// Version of the last initializer or reinitializer that ran. Every preset
    /// starts at 1; a class that needs a migration bumps it in its `migrate`.
    fn initialized_version(self: @TState) -> u64;
}
