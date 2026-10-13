// SPDX-License-Identifier: MPL-2.0
// CMTAT ExtraInformationModule: token id, terms and information under
// EXTRA_INFORMATION_ROLE. Not part of the Light preset.

#[starknet::component]
pub mod ExtraInformationComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::interfaces::erc1643::{Document, DocumentInfo};
    use crate::interfaces::extra_information::{ICMTATBase, Terms};
    use crate::roles::EXTRA_INFORMATION_ROLE;

    #[storage]
    pub struct Storage {
        pub ExtraInformationModule_token_id: ByteArray,
        pub ExtraInformationModule_terms: Terms,
        pub ExtraInformationModule_information: ByteArray,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        TokenId: TokenId,
        Terms: TermsSet,
        Information: Information,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TokenId {
        pub new_token_id: ByteArray,
    }

    /// CMTAT `Terms(CMTATTerms newTerm)`.
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct TermsSet {
        pub new_term: Terms,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct Information {
        pub new_information: ByteArray,
    }

    #[embeddable_as(CMTATBaseImpl)]
    impl CMTATBase<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of ICMTATBase<ComponentState<TContractState>> {
        fn token_id(self: @ComponentState<TContractState>) -> ByteArray {
            self.ExtraInformationModule_token_id.read()
        }

        fn terms(self: @ComponentState<TContractState>) -> Terms {
            self.ExtraInformationModule_terms.read()
        }

        fn information(self: @ComponentState<TContractState>) -> ByteArray {
            self.ExtraInformationModule_information.read()
        }

        fn set_token_id(ref self: ComponentState<TContractState>, token_id: ByteArray) {
            get_dep_component!(@self, Access).assert_only_role(EXTRA_INFORMATION_ROLE);
            self._set_token_id(token_id);
        }

        fn set_terms(ref self: ComponentState<TContractState>, terms: DocumentInfo) {
            get_dep_component!(@self, Access).assert_only_role(EXTRA_INFORMATION_ROLE);
            self._set_terms(terms);
        }

        fn set_information(ref self: ComponentState<TContractState>, information: ByteArray) {
            get_dep_component!(@self, Access).assert_only_role(EXTRA_INFORMATION_ROLE);
            self._set_information(information);
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>, +Drop<TContractState>,
    > of InternalTrait<TContractState> {
        fn initializer(
            ref self: ComponentState<TContractState>,
            token_id: ByteArray,
            terms: DocumentInfo,
            information: ByteArray,
        ) {
            self._set_token_id(token_id);
            self._set_terms(terms);
            self._set_information(information);
        }

        fn _set_token_id(ref self: ComponentState<TContractState>, token_id: ByteArray) {
            self.ExtraInformationModule_token_id.write(token_id.clone());
            self.emit(TokenId { new_token_id: token_id });
        }

        fn _set_terms(ref self: ComponentState<TContractState>, terms: DocumentInfo) {
            let new_term = Terms {
                name: terms.name,
                doc: Document {
                    uri: terms.uri,
                    document_hash: terms.document_hash,
                    last_modified: starknet::get_block_timestamp(),
                },
            };
            self.ExtraInformationModule_terms.write(new_term.clone());
            self.emit(TermsSet { new_term });
        }

        fn _set_information(ref self: ComponentState<TContractState>, information: ByteArray) {
            self.ExtraInformationModule_information.write(information.clone());
            self.emit(Information { new_information: information });
        }
    }
}
