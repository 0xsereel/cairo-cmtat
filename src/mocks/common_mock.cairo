// SPDX-License-Identifier: MPL-2.0
// Full-core mock, equivalent to CMTATBaseERC1404: every CMTATBaseCommon component
// plus the RuleEngine hook and ERC-1404, with RuleEngineHooksImpl as the check
// chain. No RuleEngine is set at deployment. The constructor mints without checks.

#[starknet::contract]
pub mod CommonMock {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::security::ReentrancyGuardComponent;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::burn::BurnComponent;
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
    use crate::components::validation::ValidationComponent;
    use crate::interfaces::erc1643::DocumentInfo;

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: PauseComponent, storage: pause, event: PauseEvent);
    component!(path: EnforcementComponent, storage: enforcement, event: EnforcementEvent);
    component!(
        path: ERC20EnforcementComponent, storage: erc20_enforcement, event: ERC20EnforcementEvent,
    );
    component!(path: ValidationComponent, storage: validation, event: ValidationEvent);
    component!(path: ERC1404Component, storage: erc1404, event: ERC1404Event);
    component!(path: RuleEngineComponent, storage: rule_engine, event: RuleEngineEvent);
    component!(
        path: ReentrancyGuardComponent, storage: reentrancy_guard, event: ReentrancyGuardEvent,
    );
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(path: MintComponent, storage: mint, event: MintEvent);
    component!(path: BurnComponent, storage: burn, event: BurnEvent);
    component!(
        path: TokenAttributesComponent, storage: token_attributes, event: TokenAttributesEvent,
    );
    component!(
        path: ExtraInformationComponent, storage: extra_information, event: ExtraInformationEvent,
    );

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
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    // Access control
    #[abi(embed_v0)]
    impl AccessControlImpl =
        CMTATAccessControlComponent::AccessControlImpl<ContractState>;
    impl AccessControlInternalImpl = CMTATAccessControlComponent::InternalImpl<ContractState>;

    // Pause
    #[abi(embed_v0)]
    impl PauseImpl = PauseComponent::PauseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC8343Impl = PauseComponent::ERC8343Impl<ContractState>;
    impl PauseInternalImpl = PauseComponent::InternalImpl<ContractState>;

    // Enforcement
    #[abi(embed_v0)]
    impl EnforcementImpl = EnforcementComponent::EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643ERC20EnforcementImpl =
        ERC20EnforcementComponent::ERC3643ERC20EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC7943FungibleEnforcementImpl =
        ERC20EnforcementComponent::ERC7943FungibleEnforcementImpl<ContractState>;

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

    // Token attributes and extra information
    #[abi(embed_v0)]
    impl ERC3643ERC20BaseImpl =
        TokenAttributesComponent::ERC3643ERC20BaseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643VersionImpl =
        TokenAttributesComponent::ERC3643VersionImpl<ContractState>;
    #[abi(embed_v0)]
    impl CMTATBaseImpl = ExtraInformationComponent::CMTATBaseImpl<ContractState>;
    impl ExtraInformationInternalImpl = ExtraInformationComponent::InternalImpl<ContractState>;

    // Compliance reads and ERC-1404
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
    #[abi(embed_v0)]
    impl ERC1404Impl = ERC1404Component::ERC1404Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC1404ExtendImpl = ERC1404Component::ERC1404ExtendImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
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
        erc1404: ERC1404Component::Storage,
        #[substorage(v0)]
        rule_engine: RuleEngineComponent::Storage,
        #[substorage(v0)]
        reentrancy_guard: ReentrancyGuardComponent::Storage,
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
        ERC1404Event: ERC1404Component::Event,
        #[flat]
        RuleEngineEvent: RuleEngineComponent::Event,
        #[flat]
        ReentrancyGuardEvent: ReentrancyGuardComponent::Event,
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
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        decimals: u8,
        initial_supply: u256,
        recipient: ContractAddress,
        admin: ContractAddress,
    ) {
        self.erc20_base.initializer("Mock", "MCK", decimals);
        self.cmtat_access.initializer(admin);
        self.pause.initializer();
        self
            .extra_information
            .initializer(
                "TOKEN-ID",
                DocumentInfo { name: "Terms", uri: "https://terms", document_hash: 0x1234 },
                "information",
            );
        self.erc20.mint(recipient, initial_supply);
    }
}
