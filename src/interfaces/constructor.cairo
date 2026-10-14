// SPDX-License-Identifier: MPL-2.0
// Constructor arguments shared by the presets (ICMTATConstructor).

use crate::interfaces::erc1643::DocumentInfo;

#[derive(Clone, Drop, Debug, PartialEq, Serde)]
pub struct ERC20Attributes {
    pub name: ByteArray,
    pub symbol: ByteArray,
    /// CMTAT specifies 0 for compliance with Swiss law; other values are allowed.
    pub decimals: u8,
}

#[derive(Clone, Drop, Debug, PartialEq, Serde)]
pub struct ExtraInformationAttributes {
    pub token_id: ByteArray,
    pub terms: DocumentInfo,
    pub information: ByteArray,
}
