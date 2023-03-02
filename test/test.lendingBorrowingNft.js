const { BN, ether, constants, expectEvent, shouldFail, time, expectRevert } = require('@openzeppelin/test-helpers');
const moment = require('moment');
const PiNFT = artifacts.require("piNFT");
const SampleERC20 = artifacts.require("mintToken");
const NftLendingBorrowing = artifacts.require("NFTlendingBorrowing");


contract("NFTlendingBorrowing", async (accounts) => {

    let piNFT, sampleERC20, nftLendBorrow;
    let alice = accounts[0];
    let validator = accounts[1];
    let bob = accounts[2];
    let royaltyReciever = accounts[3];
    let carl = accounts[4]

    it("should deploy the NFTlendingBorrowing Contract", async () => {
        piNFT = await PiNFT.deployed()
        sampleERC20 = await SampleERC20.deployed()
        nftLendBorrow = await NftLendingBorrowing.deployed();
        assert(nftLendBorrow*sampleERC20*nftLendBorrow !== undefined||""||null||NaN, "NFTLendingBorrowing contract was not deployed");
      });

      it("mint NFT and list for lending", async () => {

        const tx = await piNFT.mintNFT(alice, "URI1", [[royaltyReciever, 500]]);
        const tokenId = tx.logs[0].args.tokenId.toNumber();
        assert(tokenId === 0, "Failed to mint or wrong token Id");
        assert.equal(await piNFT.balanceOf(alice), 1, "Failed to mint");

        await piNFT.approve(nftLendBorrow.address, 0)

        const tx1 = await nftLendBorrow.listNFTforBorrowing(
            tokenId,
            piNFT.address,
            1000,
            200,
            200,
            100
        )
        const NFTid = tx1.logs[0].args.NFTid.toNumber()
        assert(NFTid===1, "Failed to list NFT for Lending") 
    })

    it("Bid for NFT", async () => {

        await sampleERC20.mint(bob, 200)
        await sampleERC20.approve(nftLendBorrow.address, 200, {from: bob})
        const tx = await nftLendBorrow.Bid(
                1,
                100,
                sampleERC20.address,
                10,
                200,
                200,
                {from:bob}
            )
        const BidId = tx.logs[0].args.BidId.toNumber()
        assert(BidId==0, "Bid not placed successfully")

        await sampleERC20.mint(carl, 200)
        await sampleERC20.approve(nftLendBorrow.address, 200, {from: carl})
        const tx2 = await nftLendBorrow.Bid(
                1,
                100,
                sampleERC20.address,
                10,
                200,
                200,
                {from:carl}
            )
            
            const BidId2 = tx2.logs[0].args.BidId.toNumber()
            assert(BidId2==1, "Bid not placed successfully")

        
    })

    it("Should Accept Bid", async () => {


        const tx = await nftLendBorrow.AcceptBid(
                1,
                0
            )
    })

    it("Should Repay Bid", async () => {

        
        await sampleERC20.approve(nftLendBorrow.address, 120)
        const tx = await nftLendBorrow.Repay(
                1,
                0
            )
            const amount = tx.logs[0].args.Amount.toNumber()
            console.log(amount)
    })

    it("Withdraw second Bid", async () => {
      await  expectRevert( nftLendBorrow.withdraw(1, 1 ,{from:carl}), "Can't withdraw Bid before expiration")

        await time.increase(time.duration.seconds(201))
        // console.log( (await time.latest()).toNumber())

        const res = await nftLendBorrow.withdraw(1, 1 ,{from:carl})
    
         assert(res.receipt.status==true, "Unable to withdraw bid")
    
    })

    it("Should remove the NFT from listing", async () => {

        const tx = await piNFT.mintNFT(alice, "URI1", [[royaltyReciever, 500]]);
        const tokenId = tx.logs[0].args.tokenId.toNumber();
        assert(tokenId === 1, "Failed to mint or wrong token Id");
        assert.equal(await piNFT.balanceOf(alice), 2, "Failed to mint");

        await piNFT.approve(nftLendBorrow.address, 1)

        const tx1 = await nftLendBorrow.listNFTforBorrowing(
            tokenId,
            piNFT.address,
            1000,
            200,
            200,
            100
        )
        const NFTid = tx1.logs[0].args.NFTid.toNumber()

        const tx2 = await nftLendBorrow.removeNFTfromList(2)
        assert(tx2.receipt.status===true, "Unable to remove NFT from listing")
    })

    

});