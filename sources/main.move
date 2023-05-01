module NFTMarketplace_res::marketplace {

    use aptos_token::token::{Self,TokenId,WithdrawCapability};
    use aptos_framework::account;
    use std::string;
    use aptos_framework::resource_account;
    use std::signer;
    use std::vector;
    use aptos_std::table::{Self, Table};
    use aptos_framework::timestamp;

    const TOKEN_NOT_MINTED:u64 = 0x1;
    const TOKEN_NOT_LISTED:u64 = 0x2;
    const YOU_ARE_NOT_OWNER_OF_THIS_TOKEN:u64 = 0x3;


    struct ListedTokenData has store,drop{
        collection_name:string::String,
        token_name:string::String,
        token_url:string::String,
        token_desc:string::String,
        creator_address:address,
        owner_address:address,
        price:u64,
        withdrawcapability:WithdrawCapability
    }

     
   

    //  struct TokenListOfUser has store,drop{
    //     collection_name:string::String,
    //     token_name:string::String,
    //     token_url:string::String,
    //     token_desc:string::String,
    //     creator_address:address,
    //     owner_address:address,
    //     price:u64,
    //     is_listed:bool
    // }

    struct NFTData has key{
        signer_cap :account::SignerCapability,
        collection_name:string::String,
        listed_tokens:Table<string::String,ListedTokenData>,
        token_and_id:Table<string::String,TokenId>
    }

    // struct UserProfile has key{
    //     username:string::String,
    //     profile_url:string::String,
    //     tokens:Table<string::String,TokenListOfUser>
    // }


    fun init_module(resource_account_add:&signer){

        let collection_name = string::utf8(b"MD-NFTCollection");
        let collection_description = string::utf8(b"NFT Market place for Minddeft.");
        let collection_url = string::utf8(b"https://media.licdn.com/dms/image/C510BAQFErwlLk8QVxQ/company-logo_200_200/0/1543485959455?e=2147483647&v=beta&t=pWOQG6uc45A1JBckVf_Nm8vsgipSTeag0X4kqhoOAYk");
        let nft_supply:u64 = 0;
        let nft_mutate_setting = vector<bool>[false,false,false];

        let resource_signer_cap = resource_account::retrieve_resource_account_cap(resource_account_add,@Owner);
        let resource_signer = account::create_signer_with_capability(&resource_signer_cap);


        token::create_collection(&resource_signer,collection_name,collection_description,collection_url,nft_supply,nft_mutate_setting);

        move_to(resource_account_add,NFTData {
            signer_cap:resource_signer_cap,
            collection_name:collection_name,
            listed_tokens:table::new<string::String,ListedTokenData>(),
            token_and_id:table::new<string::String,TokenId>(),
        });

    }

    public entry fun CreateNFT(creator:&signer,tokenname :string::String,tokendesc :string::String,tokenurl :string::String)acquires NFTData {

        let _creator_address = signer::address_of(creator);

        let nftdata = borrow_global_mut<NFTData>(@NFTMarketplace_res);

        let resource_signer = account::create_signer_with_capability(&nftdata.signer_cap);
        let resource_account_address = signer::address_of(&resource_signer);

        let token_data = token::create_tokendata(
                    &resource_signer,
                    nftdata.collection_name,
                    tokenname,
                    tokendesc,
                    1,
                    tokenurl,
                    resource_account_address,
                    1,
                    0,
                    token::create_token_mutability_config(
                        &vector<bool>[ false, false, false, false, true ]
                    ),
                    vector::empty<string::String>(),
                    vector::empty<vector<u8>>(),
                    vector::empty<string::String>(),
                    );


        let token_id = token::mint_token(&resource_signer,token_data,1);

        token::direct_transfer(&resource_signer,creator,token_id,1);

        table::add(&mut nftdata.token_and_id,tokenname,token_id);

        // if(exists<UserProfile>(signer::address_of(creator))){

        //     let uprofile = borrow_global_mut<UserProfile>(signer::address_of(creator));

        //     table::add(&mut uprofile.tokens,tokenname,
        //     TokenListOfUser {
        //         collection_name:nftdata.collection_name,
        //         token_name:tokenname,
        //         token_url:tokenurl,
        //         token_desc:tokendesc,
        //         creator_address:@NFTMarketplace_res,
        //         owner_address:signer::address_of(creator),
        //         price:0,
        //         is_listed:false
        //     }
        //     );


        // }else{

        //     let tab = table::new<string::String,TokenListOfUser>();

        //     table::add(&mut tab,tokenname,
        //     TokenListOfUser {
        //         collection_name:nftdata.collection_name,
        //         token_name:tokenname,
        //         token_url:tokenurl,
        //         token_desc:tokendesc,
        //         creator_address:@NFTMarketplace_res,
        //         owner_address:signer::address_of(creator),
        //         price:0,
        //         is_listed:false
        //     }
        //     ); 

        //     move_to(creator,UserProfile{
        //         username:string::utf8(b"NFTIOUSER"),
        //         profile_url:string::utf8(b"https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460__340.png"),
        //         tokens:tab
        //     });
        // }

    }

    public entry fun ListToken(tokenlistner:&signer,collection_name:string::String,token_name:string::String,token_url:string::String,token_desc:string::String,owner_address:address,price:u64,expire_time:u64)acquires NFTData{

        let nftdata = borrow_global_mut<NFTData>(@NFTMarketplace_res);
        
        assert!(table::contains(&nftdata.token_and_id,token_name),TOKEN_NOT_MINTED);

        let token_id = table::borrow(&nftdata.token_and_id,token_name);
        
        let wid_cap = token::create_withdraw_capability(tokenlistner,*token_id,1,expire_time);

        table::add(&mut nftdata.listed_tokens,token_name,ListedTokenData{
            collection_name:collection_name,
            token_name:token_name,
            token_url:token_url,
            token_desc:token_desc,
            creator_address:@NFTMarketplace_res,
            owner_address:owner_address,
            price:price,
            withdrawcapability:wid_cap
        });

    }

    public entry fun RemoveFromListing(tokenlistner:&signer,token_name:string::String)acquires NFTData{

        let nftdata = borrow_global_mut<NFTData>(@NFTMarketplace_res);
        let tokenlistner_address = signer::address_of(tokenlistner);

        assert!(table::contains(&nftdata.listed_tokens,token_name),TOKEN_NOT_LISTED);

        let tokendata = table::borrow(&nftdata.listed_tokens,token_name);

        assert!(tokendata.owner_address == tokenlistner_address,YOU_ARE_NOT_OWNER_OF_THIS_TOKEN);

        table::remove(&mut nftdata.listed_tokens,token_name);

    }

    public entry fun BuyToken(receiver:&signer,token_name:string::String)acquires NFTData{

        let nftdata = borrow_global_mut<NFTData>(@NFTMarketplace_res);

        assert!(table::contains(&nftdata.listed_tokens,token_name),TOKEN_NOT_LISTED);


        let ListedTokenData {
            collection_name:_,
            token_name:_,
            token_url:_,
            token_desc:_,
            creator_address:_,
            owner_address,
            price,
            withdrawcapability
        } = table::remove(&mut nftdata.listed_tokens,token_name);

        // let with_coin = coin::withdraw<0x1::aptos_coin::AptosCoin>(receiver,price);

        // coin::extract<>()

        0x1::aptos_account::transfer_coins<0x1::aptos_coin::AptosCoin>(receiver,owner_address,price);

        let token = token::withdraw_with_capability(withdrawcapability);

        token::deposit_token(receiver,token);

    }


    public entry fun offer_token(sender:signer,receiver:address,creator: address,collection_name:string::String,token_name:string::String){
    0x3::token_transfers::offer_script(sender,receiver,creator,collection_name,token_name,0,1);
     } 

   public entry fun claim_token(receiver: signer, sender: address, creator: address, collection_name: string::String, token_name: string::String){
    0x3::token_transfers::claim_script(receiver,sender,creator,collection_name,token_name,0);
    }


    #[test]
    public fun test(){

        assert!(timestamp::now_seconds() <= 1682417106, 1);
    }




}