// SPDX-License-Identifier: MPL-2.0
// CMTAT DocumentERC1643Module: documents stored in the token under DOCUMENT_ROLE.
// Not part of the Light preset. Removal swaps the last name into the freed slot,
// so `get_all_documents` order is not stable across removals (as in CMTAT).

#[starknet::component]
pub mod DocumentsComponent {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use starknet::storage::{
        Map, MutableVecTrait, StorageMapReadAccess, StorageMapWriteAccess, StoragePathEntry,
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait,
    };
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::access::CMTATAccessControlComponent::InternalImpl as AccessInternalImpl;
    use crate::errors;
    use crate::interfaces::erc1643::{Document, IERC1643};
    use crate::roles::DOCUMENT_ROLE;

    #[storage]
    pub struct Storage {
        pub DocumentERC1643Module_documents: Map<felt252, Document>,
        /// 1-based index into `DocumentERC1643Module_names`; 0 means absent.
        pub DocumentERC1643Module_keys: Map<felt252, u64>,
        pub DocumentERC1643Module_names: Vec<felt252>,
    }

    #[event]
    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        DocumentUpdated: DocumentUpdated,
        DocumentRemoved: DocumentRemoved,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DocumentUpdated {
        #[key]
        pub name: felt252,
        pub uri: ByteArray,
        pub document_hash: u256,
    }

    #[derive(Drop, Debug, PartialEq, starknet::Event)]
    pub struct DocumentRemoved {
        #[key]
        pub name: felt252,
        pub uri: ByteArray,
        pub document_hash: u256,
    }

    #[embeddable_as(ERC1643Impl)]
    impl ERC1643<
        TContractState,
        +HasComponent<TContractState>,
        +SRC5Component::HasComponent<TContractState>,
        +AccessControlComponent::HasComponent<TContractState>,
        impl Access: CMTATAccessControlComponent::HasComponent<TContractState>,
        +Drop<TContractState>,
    > of IERC1643<ComponentState<TContractState>> {
        fn get_document(
            self: @ComponentState<TContractState>, name: felt252,
        ) -> (ByteArray, u256, u64) {
            let document = self.DocumentERC1643Module_documents.read(name);
            (document.uri, document.document_hash, document.last_modified)
        }

        fn get_all_documents(self: @ComponentState<TContractState>) -> Array<felt252> {
            let mut names = array![];
            for i in 0..self.DocumentERC1643Module_names.len() {
                names.append(self.DocumentERC1643Module_names.at(i).read());
            }
            names
        }

        fn set_document(
            ref self: ComponentState<TContractState>,
            name: felt252,
            uri: ByteArray,
            document_hash: u256,
        ) {
            get_dep_component!(@self, Access).assert_only_role(DOCUMENT_ROLE);
            assert(name != 0, errors::ERC1643_INVALID_NAME);
            self
                .DocumentERC1643Module_documents
                .write(
                    name,
                    Document {
                        uri: uri.clone(),
                        document_hash,
                        last_modified: starknet::get_block_timestamp(),
                    },
                );
            if self.DocumentERC1643Module_keys.read(name) == 0 {
                self.DocumentERC1643Module_names.push(name);
                self.DocumentERC1643Module_keys.write(name, self.DocumentERC1643Module_names.len());
            }
            self.emit(DocumentUpdated { name, uri, document_hash });
        }

        fn remove_document(ref self: ComponentState<TContractState>, name: felt252) {
            get_dep_component!(@self, Access).assert_only_role(DOCUMENT_ROLE);
            let key = self.DocumentERC1643Module_keys.read(name);
            assert(key != 0, errors::ERC1643_MISSING_DOCUMENT);
            let document = self.DocumentERC1643Module_documents.read(name);
            let index = key - 1;
            let last_index = self.DocumentERC1643Module_names.len() - 1;
            if index != last_index {
                let moved = self.DocumentERC1643Module_names.at(last_index).read();
                self.DocumentERC1643Module_names.at(index).write(moved);
                self.DocumentERC1643Module_keys.write(moved, key);
            }
            let _ = self.DocumentERC1643Module_names.pop();
            self
                .DocumentERC1643Module_documents
                .write(name, Document { uri: "", document_hash: 0, last_modified: 0 });
            self.DocumentERC1643Module_keys.entry(name).write(0);
            self
                .emit(
                    DocumentRemoved {
                        name, uri: document.uri, document_hash: document.document_hash,
                    },
                );
        }
    }
}
