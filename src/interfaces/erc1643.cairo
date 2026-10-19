// SPDX-License-Identifier: MPL-2.0
// ERC-1643 document management (CMTAT variant).
//
// Document names are `felt252` short strings, so they hold at most 31 bytes,
// one fewer than Solidity's `bytes32`. Document hashes are `u256`.

/// SNIP-5 id of ERC-1643 (CMTAT's `0xecfecec8`): XOR of the extended selectors of
/// `get_document(felt252)->((Array<bytes31>,felt252,u32),(u128,u128),u64)`,
/// `get_all_documents()->Array<felt252>`,
/// `set_document(felt252,(Array<bytes31>,felt252,u32),(u128,u128))` and
/// `remove_document(felt252)`.
pub const IERC1643_ID: felt252 = 0x1a10ec61334b275b2f19413a43f011e7465e9f29c94a34b07b7d33c2bb93d50;

/// A document stored on chain. `last_modified` is set by the contract.
#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct Document {
    pub uri: ByteArray,
    /// A 256-bit content hash does not fit in a felt.
    pub document_hash: u256,
    pub last_modified: u64,
}

/// Caller-supplied document fields (`IERC1643CMTAT.DocumentInfo`).
#[derive(Clone, Drop, Debug, PartialEq, Serde)]
pub struct DocumentInfo {
    pub name: ByteArray,
    pub uri: ByteArray,
    pub document_hash: u256,
}

#[starknet::interface]
pub trait IERC1643<TState> {
    /// Returns `(uri, document_hash, last_modified)`; all zero if the name is unknown.
    fn get_document(self: @TState, name: felt252) -> (ByteArray, u256, u64);
    fn get_all_documents(self: @TState) -> Array<felt252>;
    /// Adds or updates a document. Requires DOCUMENT_ROLE and a non-zero name.
    fn set_document(ref self: TState, name: felt252, uri: ByteArray, document_hash: u256);
    /// Requires DOCUMENT_ROLE and an existing document.
    fn remove_document(ref self: TState, name: felt252);
}
