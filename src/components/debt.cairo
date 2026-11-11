// SPDX-License-Identifier: MPL-2.0
// CMTAT DebtModule: structured debt information and credit events under
// DEBT_ROLE. Setters emit CMTAT's lightweight log events, without payload.
// There is no DebtEngine; that belongs to a separate preset.

#[starknet::component]
pub mod DebtComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::interfaces::debt::{CreditEvents, DebtInformation, DebtInstrument, IDebtModule};
    use crate::roles::DEBT_ROLE;

    #[storage]
    pub struct Storage {
        pub DebtModule_debt: DebtInformation,
        pub DebtModule_credit_events: CreditEvents,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        DebtLogEvent: DebtLogEvent,
        DebtInstrumentLogEvent: DebtInstrumentLogEvent,
        CreditEventsLogEvent: CreditEventsLogEvent,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DebtLogEvent {}

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DebtInstrumentLogEvent {}

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct CreditEventsLogEvent {}

    #[embeddable_as(DebtModuleImpl)]
    impl DebtModule<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IDebtModule<ComponentState<TContractState>> {
        fn debt(self: @ComponentState<TContractState>) -> DebtInformation {
            self.DebtModule_debt.read()
        }

        fn credit_events(self: @ComponentState<TContractState>) -> CreditEvents {
            self.DebtModule_credit_events.read()
        }

        fn set_debt(ref self: ComponentState<TContractState>, debt: DebtInformation) {
            get_dep_component!(@self, Access).assert_only_role(DEBT_ROLE);
            self.DebtModule_debt.write(debt);
            self.emit(DebtLogEvent {});
        }

        fn set_debt_instrument(
            ref self: ComponentState<TContractState>, debt_instrument: DebtInstrument,
        ) {
            get_dep_component!(@self, Access).assert_only_role(DEBT_ROLE);
            let mut debt = self.DebtModule_debt.read();
            debt.debt_instrument = debt_instrument;
            self.DebtModule_debt.write(debt);
            self.emit(DebtInstrumentLogEvent {});
        }

        fn set_credit_events(
            ref self: ComponentState<TContractState>, credit_events: CreditEvents,
        ) {
            get_dep_component!(@self, Access).assert_only_role(DEBT_ROLE);
            self.DebtModule_credit_events.write(credit_events);
            self.emit(CreditEventsLogEvent {});
        }
    }
}
