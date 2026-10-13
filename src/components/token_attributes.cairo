// SPDX-License-Identifier: MPL-2.0
// CMTAT TokenAttributeModule (mutable name and symbol under DEFAULT_ADMIN_ROLE)
// and VersionModule. Name and symbol live in OpenZeppelin ERC-20 storage, read
// through ERC20BaseComponent's metadata impl.

#[starknet::component]
pub mod TokenAttributesComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::ERC20Component;
    use starknet::storage::StoragePointerWriteAccess;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::interfaces::token_attributes::{IERC3643ERC20Base, IERC3643Version};
    use crate::roles::DEFAULT_ADMIN_ROLE;

    #[storage]
    pub struct Storage {}

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Name: Name,
        Symbol: Symbol,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Name {
        pub new_name: ByteArray,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Symbol {
        pub new_symbol: ByteArray,
    }

    #[embeddable_as(ERC3643ERC20BaseImpl)]
    impl ERC3643ERC20Base<
        TContractState,
        +HasComponent<TContractState>,
        impl ERC20: ERC20Component::HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC3643ERC20Base<ComponentState<TContractState>> {
        fn set_name(ref self: ComponentState<TContractState>, name: ByteArray) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.ERC20_name.write(name.clone());
            self.emit(Name { new_name: name });
        }

        fn set_symbol(ref self: ComponentState<TContractState>, symbol: ByteArray) {
            get_dep_component!(@self, Access).assert_only_role(DEFAULT_ADMIN_ROLE);
            let mut erc20 = get_dep_component_mut!(ref self, ERC20);
            erc20.ERC20_symbol.write(symbol.clone());
            self.emit(Symbol { new_symbol: symbol });
        }
    }

    #[embeddable_as(ERC3643VersionImpl)]
    impl ERC3643Version<
        TContractState, +HasComponent<TContractState>,
    > of IERC3643Version<ComponentState<TContractState>> {
        fn version(self: @ComponentState<TContractState>) -> ByteArray {
            "3.3.0"
        }
    }
}
