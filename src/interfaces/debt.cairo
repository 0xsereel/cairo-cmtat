// SPDX-License-Identifier: MPL-2.0
// CMTAT debt information and credit events (ICMTATDebt, ICMTATCreditEvents,
// IDebtModule). Rates and amounts are `u256`, as in Solidity.

use starknet::ContractAddress;

#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct DebtIdentifier {
    pub issuer_name: ByteArray,
    pub issuer_description: ByteArray,
    pub guarantor: ByteArray,
    pub debt_holder: ByteArray,
}

#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct DebtInstrument {
    pub interest_rate: u256,
    pub par_value: u256,
    pub minimum_denomination: u256,
    pub issuance_date: ByteArray,
    pub maturity_date: ByteArray,
    pub coupon_payment_frequency: ByteArray,
    pub interest_schedule_format: ByteArray,
    pub interest_payment_date: ByteArray,
    pub day_count_convention: ByteArray,
    pub business_day_convention: ByteArray,
    pub currency: ByteArray,
    pub currency_contract: ContractAddress,
}

#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct DebtInformation {
    pub debt_identifier: DebtIdentifier,
    pub debt_instrument: DebtInstrument,
}

#[derive(Clone, Drop, Debug, PartialEq, Serde, starknet::Store)]
pub struct CreditEvents {
    pub flag_default: bool,
    pub flag_redeemed: bool,
    pub rating: ByteArray,
}

#[starknet::interface]
pub trait IDebtModule<TState> {
    fn debt(self: @TState) -> DebtInformation;
    fn credit_events(self: @TState) -> CreditEvents;
    /// Requires DEBT_ROLE.
    fn set_debt(ref self: TState, debt: DebtInformation);
    /// Requires DEBT_ROLE. Replaces only the instrument part of the debt.
    fn set_debt_instrument(ref self: TState, debt_instrument: DebtInstrument);
    /// Requires DEBT_ROLE.
    fn set_credit_events(ref self: TState, credit_events: CreditEvents);
}
