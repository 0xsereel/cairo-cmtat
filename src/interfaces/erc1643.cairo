// SPDX-License-Identifier: MPL-2.0
// ERC-1643 document types (CMTAT variant). The ERC-1643 trait is added with the
// documents component.

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
