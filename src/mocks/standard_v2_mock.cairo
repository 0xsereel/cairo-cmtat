// SPDX-License-Identifier: MPL-2.0
// Upgrade target for tests: CMTATStandard plus a `migrate` entry point that
// bumps the storage version to 2 and fills one new storage field from existing
// data. Shows the migration pattern documented in components/upgrade.cairo.

#[starknet::interface]
pub trait IStandardV2Mock<TState> {
    /// Requires DEFAULT_ADMIN_ROLE; runs once.
    fn migrate(ref self: TState);
    /// Written by `migrate`: total supply when the migration ran.
    fn supply_at_migration(self: @TState) -> u256;
}

#[starknet::contract]
pub mod CMTATStandardV2Mock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::ContractAddress;
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::burn::BurnComponent;
    use crate::components::documents::DocumentsComponent;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::erc1404::ERC1404Component;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::erc20_enforcement::ERC20EnforcementComponent;
    use crate::components::extra_information::ExtraInformationComponent;
    use crate::components::hooks::RuleEngineHooksImpl;
    use crate::components::mint::MintComponent;
    use crate::components::pause::PauseComponent;
    use crate::components::rule_engine::RuleEngineComponent;
    use crate::components::token_attributes::TokenAttributesComponent;
    use crate::components::upgrade::UpgradeComponent;
    use crate::components::validation::ValidationComponent;
    use crate::interfaces::constructor::{ERC20Attributes, ExtraInformationAttributes};
    use crate::interfaces::erc1404::{IERC1404_EXTEND_ID, IERC1404_ID};
    use crate::interfaces::erc1643::IERC1643_ID;
    use crate::interfaces::erc20_enforcement::IERC7943_ID;
    use crate::interfaces::mint::IERC5679_ID;

    // OpenZeppelin
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );
    // CMTAT
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: PauseComponent, storage: pause, event: PauseEvent);
    component!(path: EnforcementComponent, storage: enforcement, event: EnforcementEvent);
    component!(
        path: ERC20EnforcementComponent, storage: erc20_enforcement, event: ERC20EnforcementEvent,
    );
    component!(path: ValidationComponent, storage: validation, event: ValidationEvent);
    component!(path: RuleEngineComponent, storage: rule_engine, event: RuleEngineEvent);
    component!(path: ERC1404Component, storage: erc1404, event: ERC1404Event);
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(path: MintComponent, storage: mint, event: MintEvent);
    component!(path: BurnComponent, storage: burn, event: BurnEvent);
    component!(
        path: TokenAttributesComponent, storage: token_attributes, event: TokenAttributesEvent,
    );
    component!(
        path: ExtraInformationComponent, storage: extra_information, event: ExtraInformationEvent,
    );
    component!(path: DocumentsComponent, storage: documents, event: DocumentsEvent);
    component!(path: UpgradeComponent, storage: upgrade, event: UpgradeEvent);

    // ERC-20
    #[abi(embed_v0)]
    impl ERC20Impl = ERC20BaseComponent::ERC20Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20CamelOnlyImpl = ERC20BaseComponent::ERC20CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20MetadataImpl = ERC20BaseComponent::ERC20MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC20BatchBalanceImpl =
        ERC20BaseComponent::ERC20BatchBalanceImpl<ContractState>;
    impl ERC20BaseInternalImpl = ERC20BaseComponent::InternalImpl<ContractState>;

    // Access control and introspection
    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;
    impl SRC5InternalImpl = SRC5Component::InternalImpl<ContractState>;

    // Pause and ERC-8343
    #[abi(embed_v0)]
    impl PauseImpl = PauseComponent::PauseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC8343Impl = PauseComponent::ERC8343Impl<ContractState>;
    impl PauseInternalImpl = PauseComponent::InternalImpl<ContractState>;

    // Address freeze, partial freeze and forced transfer
    #[abi(embed_v0)]
    impl EnforcementImpl = EnforcementComponent::EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl CMTATEnforcementImpl =
        EnforcementComponent::CMTATEnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643ERC20EnforcementImpl =
        ERC20EnforcementComponent::ERC3643ERC20EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC7943FungibleEnforcementImpl =
        ERC20EnforcementComponent::ERC7943FungibleEnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC7551ERC20EnforcementImpl =
        ERC20EnforcementComponent::ERC7551ERC20EnforcementImpl<ContractState>;

    // Compliance reads, RuleEngine and ERC-1404
    #[abi(embed_v0)]
    impl ERC7943SendReceiveImpl =
        ValidationComponent::ERC7943SendReceiveImpl<ContractState>;
    #[abi(embed_v0)]
    impl ComplianceReadImpl =
        RuleEngineComponent::ComplianceReadImpl<ContractState>;
    #[abi(embed_v0)]
    impl ComplianceReadFromImpl =
        RuleEngineComponent::ComplianceReadFromImpl<ContractState>;
    #[abi(embed_v0)]
    impl ValidationRuleEngineImpl =
        RuleEngineComponent::ValidationRuleEngineImpl<ContractState>;
    impl RuleEngineInternalImpl = RuleEngineComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1404Impl = ERC1404Component::ERC1404Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1404ExtendImpl = ERC1404Component::ERC1404ExtendImpl<ContractState>;

    // Mint
    #[abi(embed_v0)]
    impl ERC3643MintImpl = MintComponent::ERC3643MintImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643BatchTransferImpl =
        MintComponent::ERC3643BatchTransferImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC5679MintImpl = MintComponent::ERC5679MintImpl<ContractState>;

    // Burn
    #[abi(embed_v0)]
    impl ERC3643BurnImpl = BurnComponent::ERC3643BurnImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC5679BurnImpl = BurnComponent::ERC5679BurnImpl<ContractState>;
    #[abi(embed_v0)]
    impl BurnBatchImpl = BurnComponent::BurnBatchImpl<ContractState>;
    #[abi(embed_v0)]
    impl BurnFromImpl = BurnComponent::BurnFromImpl<ContractState>;
    #[abi(embed_v0)]
    impl BurnMintImpl = BurnComponent::BurnMintImpl<ContractState>;

    // Token attributes, version, extra information and documents
    #[abi(embed_v0)]
    impl ERC3643ERC20BaseImpl =
        TokenAttributesComponent::ERC3643ERC20BaseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643VersionImpl =
        TokenAttributesComponent::ERC3643VersionImpl<ContractState>;
    #[abi(embed_v0)]
    impl CMTATBaseImpl = ExtraInformationComponent::CMTATBaseImpl<ContractState>;
    impl ExtraInformationInternalImpl = ExtraInformationComponent::InternalImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1643Impl = DocumentsComponent::ERC1643Impl<ContractState>;

    // Upgrades
    #[abi(embed_v0)]
    impl UpgradeableImpl = UpgradeComponent::UpgradeableImpl<ContractState>;
    #[abi(embed_v0)]
    impl UpgradeVersionImpl = UpgradeComponent::UpgradeVersionImpl<ContractState>;
    impl UpgradeInternalImpl = UpgradeComponent::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        V2Mock_supply_at_migration: u256,
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
        #[substorage(v0)]
        cmtat_access: CMTATAccessControlComponent::Storage,
        #[substorage(v0)]
        pause: PauseComponent::Storage,
        #[substorage(v0)]
        enforcement: EnforcementComponent::Storage,
        #[substorage(v0)]
        erc20_enforcement: ERC20EnforcementComponent::Storage,
        #[substorage(v0)]
        validation: ValidationComponent::Storage,
        #[substorage(v0)]
        rule_engine: RuleEngineComponent::Storage,
        #[substorage(v0)]
        erc1404: ERC1404Component::Storage,
        #[substorage(v0)]
        erc20_base: ERC20BaseComponent::Storage,
        #[substorage(v0)]
        mint: MintComponent::Storage,
        #[substorage(v0)]
        burn: BurnComponent::Storage,
        #[substorage(v0)]
        token_attributes: TokenAttributesComponent::Storage,
        #[substorage(v0)]
        extra_information: ExtraInformationComponent::Storage,
        #[substorage(v0)]
        documents: DocumentsComponent::Storage,
        #[substorage(v0)]
        upgrade: UpgradeComponent::Storage,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event,
        #[flat]
        AccessControlEvent: AccessControlComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        #[flat]
        UpgradeableEvent: UpgradeableComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
        #[flat]
        CMTATAccessControlEvent: CMTATAccessControlComponent::Event,
        #[flat]
        PauseEvent: PauseComponent::Event,
        #[flat]
        EnforcementEvent: EnforcementComponent::Event,
        #[flat]
        ERC20EnforcementEvent: ERC20EnforcementComponent::Event,
        #[flat]
        ValidationEvent: ValidationComponent::Event,
        #[flat]
        RuleEngineEvent: RuleEngineComponent::Event,
        #[flat]
        ERC1404Event: ERC1404Component::Event,
        #[flat]
        ERC20BaseEvent: ERC20BaseComponent::Event,
        #[flat]
        MintEvent: MintComponent::Event,
        #[flat]
        BurnEvent: BurnComponent::Event,
        #[flat]
        TokenAttributesEvent: TokenAttributesComponent::Event,
        #[flat]
        ExtraInformationEvent: ExtraInformationComponent::Event,
        #[flat]
        DocumentsEvent: DocumentsComponent::Event,
        #[flat]
        UpgradeEvent: UpgradeComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        erc20_attributes: ERC20Attributes,
        extra_information_attributes: ExtraInformationAttributes,
        rule_engine: ContractAddress,
    ) {
        self.cmtat_access.initializer(admin);
        self.upgrade.initializer(V2);
        self.src5.register_interface(IERC5679_ID);
        self.src5.register_interface(IERC7943_ID);
        self.src5.register_interface(IERC1643_ID);
        self.src5.register_interface(IERC1404_ID);
        self.src5.register_interface(IERC1404_EXTEND_ID);
        self.pause.initializer();
        let ERC20Attributes { name, symbol, decimals } = erc20_attributes;
        self.erc20_base.initializer(name, symbol, decimals);
        let ExtraInformationAttributes {
            token_id, terms, information,
        } = extra_information_attributes;
        self.extra_information.initializer(token_id, terms, information);
        self.rule_engine.initializer(rule_engine);
    }

    const V2: u64 = 2;

    #[abi(embed_v0)]
    impl StandardV2MockImpl of super::IStandardV2Mock<ContractState> {
        fn migrate(ref self: ContractState) {
            self.upgrade.reinitializer(V2);
            let supply = self.erc20.ERC20_total_supply.read();
            self.V2Mock_supply_at_migration.write(supply);
        }

        fn supply_at_migration(self: @ContractState) -> u256 {
            self.V2Mock_supply_at_migration.read()
        }
    }
}
