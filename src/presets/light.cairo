// SPDX-License-Identifier: MPL-2.0
// CMTAT Light (CMTATBaseCore): ERC-20 with pause / ERC-8343 deactivation, address
// freeze, mint, burn, burn-and-mint and forced burn. No partial freeze, extra
// information or documents. Upgradeable under DEFAULT_ADMIN_ROLE.

#[starknet::contract]
pub mod CMTATLight {
    use openzeppelin::access::accesscontrol::AccessControlComponent;
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use openzeppelin::upgrades::UpgradeableComponent;
    use starknet::ContractAddress;
    use crate::components::access::CMTATAccessControlComponent;
    use crate::components::burn::BurnComponent;
    use crate::components::enforcement::EnforcementComponent;
    use crate::components::erc20_base::ERC20BaseComponent;
    use crate::components::forced_burn::ForcedBurnComponent;
    use crate::components::hooks::CoreHooksImpl;
    use crate::components::mint::MintComponent;
    use crate::components::pause::PauseComponent;
    use crate::components::token_attributes::TokenAttributesComponent;
    use crate::components::upgrade::UpgradeComponent;
    use crate::components::validation::ValidationComponent;

    // OpenZeppelin
    component!(path: ERC20Component, storage: erc20, event: ERC20Event);
    component!(path: AccessControlComponent, storage: access_control, event: AccessControlEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);
    component!(path: UpgradeableComponent, storage: upgradeable, event: UpgradeableEvent);
    // CMTAT
    component!(
        path: CMTATAccessControlComponent, storage: cmtat_access, event: CMTATAccessControlEvent,
    );
    component!(path: PauseComponent, storage: pause, event: PauseEvent);
    component!(path: EnforcementComponent, storage: enforcement, event: EnforcementEvent);
    component!(path: ValidationComponent, storage: validation, event: ValidationEvent);
    component!(path: ERC20BaseComponent, storage: erc20_base, event: ERC20BaseEvent);
    component!(path: MintComponent, storage: mint, event: MintEvent);
    component!(path: BurnComponent, storage: burn, event: BurnEvent);
    component!(path: ForcedBurnComponent, storage: forced_burn, event: ForcedBurnEvent);
    component!(
        path: TokenAttributesComponent, storage: token_attributes, event: TokenAttributesEvent,
    );
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

    // Pause and ERC-8343
    #[abi(embed_v0)]
    impl PauseImpl = PauseComponent::PauseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC8343Impl = PauseComponent::ERC8343Impl<ContractState>;
    impl PauseInternalImpl = PauseComponent::InternalImpl<ContractState>;

    // Compliance reads (module checks only)
    #[abi(embed_v0)]
    impl ERC7943SendReceiveImpl =
        ValidationComponent::ERC7943SendReceiveImpl<ContractState>;
    #[abi(embed_v0)]
    impl ComplianceReadImpl =
        ValidationComponent::ComplianceReadCoreImpl<ContractState>;
    #[abi(embed_v0)]
    impl ComplianceReadFromImpl =
        ValidationComponent::ComplianceReadFromCoreImpl<ContractState>;

    // Address freeze
    #[abi(embed_v0)]
    impl EnforcementImpl = EnforcementComponent::EnforcementImpl<ContractState>;
    #[abi(embed_v0)]
    impl CMTATEnforcementImpl =
        EnforcementComponent::CMTATEnforcementImpl<ContractState>;

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
    impl BurnMintImpl = BurnComponent::BurnMintImpl<ContractState>;
    #[abi(embed_v0)]
    impl ForcedBurnImpl = ForcedBurnComponent::ForcedBurnImpl<ContractState>;

    // Token attributes and version
    #[abi(embed_v0)]
    impl ERC3643ERC20BaseImpl =
        TokenAttributesComponent::ERC3643ERC20BaseImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC3643VersionImpl =
        TokenAttributesComponent::ERC3643VersionImpl<ContractState>;

    // Upgrades
    #[abi(embed_v0)]
    impl UpgradeableImpl = UpgradeComponent::UpgradeableImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage,
        #[substorage(v0)]
        access_control: AccessControlComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        #[substorage(v0)]
        upgradeable: UpgradeableComponent::Storage,
        #[substorage(v0)]
        cmtat_access: CMTATAccessControlComponent::Storage,
        #[substorage(v0)]
        pause: PauseComponent::Storage,
        #[substorage(v0)]
        enforcement: EnforcementComponent::Storage,
        #[substorage(v0)]
        validation: ValidationComponent::Storage,
        #[substorage(v0)]
        erc20_base: ERC20BaseComponent::Storage,
        #[substorage(v0)]
        mint: MintComponent::Storage,
        #[substorage(v0)]
        burn: BurnComponent::Storage,
        #[substorage(v0)]
        forced_burn: ForcedBurnComponent::Storage,
        #[substorage(v0)]
        token_attributes: TokenAttributesComponent::Storage,
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
        CMTATAccessControlEvent: CMTATAccessControlComponent::Event,
        #[flat]
        PauseEvent: PauseComponent::Event,
        #[flat]
        EnforcementEvent: EnforcementComponent::Event,
        #[flat]
        ValidationEvent: ValidationComponent::Event,
        #[flat]
        ERC20BaseEvent: ERC20BaseComponent::Event,
        #[flat]
        MintEvent: MintComponent::Event,
        #[flat]
        BurnEvent: BurnComponent::Event,
        #[flat]
        ForcedBurnEvent: ForcedBurnComponent::Event,
        #[flat]
        TokenAttributesEvent: TokenAttributesComponent::Event,
        #[flat]
        UpgradeEvent: UpgradeComponent::Event,
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
        admin: ContractAddress,
        name: ByteArray,
        symbol: ByteArray,
        decimals: u8,
    ) {
        self.cmtat_access.initializer(admin);
        self.pause.initializer();
        self.erc20_base.initializer(name, symbol, decimals);
    }
}
