use starknet::ContractAddress;

#[starknet::interface]
pub trait IDynamicNFT<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress) -> u256;
    fn set_base_uri(ref self: TContractState, base_uri: ByteArray);
}


#[starknet::contract]
mod DynamicNFT {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use starknet::{ContractAddress, get_caller_address};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    // ERC721
    #[abi(embed_v0)]
    impl ERC721Impl = ERC721Component::ERC721Impl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataImpl = ERC721Component::ERC721MetadataImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721CamelOnly = ERC721Component::ERC721CamelOnlyImpl<ContractState>;
    #[abi(embed_v0)]
    impl ERC721MetadataCamelOnly =
        ERC721Component::ERC721MetadataCamelOnlyImpl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        total_count: u32,
        owner: ContractAddress,
        mint_count_list: LegacyMap<ContractAddress, u8>,
        claim_limit_per_addrees: u8,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        SRC5Event: SRC5Component::Event
    }

    mod Errors {
        pub const ONLY_OWNER: felt252 = 'Only owner can do operation';
    }

    #[constructor]
    fn constructor(
        ref self: ContractState, owner: ContractAddress, claim_limit_per_addrees: u8) {
        let name = "DynamicNFT";
        let symbol = "DNFT";
        let base_uri = "https://mint-my-moments.vercel.app/api?id=";
        let token_id = 1;

        self.erc721.initializer(name, symbol, base_uri);
        self.owner.write(owner);
        self.erc721._mint(owner, token_id);
        self.total_count.write(1);
        self.claim_limit_per_addrees.write(claim_limit_per_addrees);
    }


    #[abi(embed_v0)]
    impl IDynamicNFTImpl of super::IDynamicNFT<ContractState> {
        fn mint(ref self: ContractState, recipient: ContractAddress) -> u256 {
            // assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            let already_claimed_count = self.mint_count_list.read(get_caller_address());
            assert(already_claimed_count < self.claim_limit_per_addrees.read(), 'Claim limit reached');
            let token_id = self.total_count.read() + 1;
            self.total_count.write(token_id);
            self.erc721._mint(recipient, token_id.into());
            self.mint_count_list.write(get_caller_address(), already_claimed_count + 1);
            token_id.into()
        }
        fn set_base_uri(ref self: ContractState, base_uri: ByteArray) {
            assert(get_caller_address() == self.owner.read(), Errors::ONLY_OWNER);
            self.erc721._set_base_uri(base_uri);
        }
    }
}
