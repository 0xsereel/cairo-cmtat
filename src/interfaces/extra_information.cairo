// SPDX-License-Identifier: MPL-2.0
// CMTAT base information: token id, terms and free-text information.

use crate::interfaces::erc1643::{Document, DocumentInfo};

/// `ICMTATBase.CMTATTerms`.
#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct Terms {
    pub name: ByteArray,
    pub doc: Document,
}

#[starknet::interface]
pub trait ICMTATBase<TState> {
    fn token_id(self: @TState) -> ByteArray;
    fn terms(self: @TState) -> Terms;
    fn information(self: @TState) -> ByteArray;
    fn set_token_id(ref self: TState, token_id: ByteArray);
    /// Sets the terms; `last_modified` is the block timestamp.
    fn set_terms(ref self: TState, terms: DocumentInfo);
    fn set_information(ref self: TState, information: ByteArray);
}
