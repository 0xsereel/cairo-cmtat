// SPDX-License-Identifier: MPL-2.0
// Class upgrades (`replace_class`) under DEFAULT_ADMIN_ROLE, over OpenZeppelin's
// UpgradeableComponent. Storage persists across upgrades, so every component
// uses module-prefixed storage names.

#[starknet::component]
pub mod UpgradeComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::interfaces::upgrades::IUpgradeable;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::upgrades::UpgradeableComponent;
    use openzeppelin::upgrades::UpgradeableComponent::InternalImpl as UpgradeableInternalImpl;
    use starknet::ClassHash;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {}

    #[embeddable_as(UpgradeableImpl)]
    impl Upgradeable<
        TContractState,
        +HasComponent<TContractState>,
        impl OZUpgradeable: UpgradeableComponent::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IUpgradeable<ComponentState<TContractState>> {
        fn upgrade(ref self: ComponentState<TContractState>, new_class_hash: ClassHash) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            get_dep_component_mut!(ref self, OZUpgradeable).upgrade(new_class_hash);
        }
    }
}
