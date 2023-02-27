const BigNumber = require("big-number");
const PiNFT = artifacts.require("piNFT");
const SampleERC20 = artifacts.require("mintToken");
const PiMarket = artifacts.require("piMarket");
// require("dotenv").config();

contract("PiMarket", async (accounts) => {
  let piNFT, sampleERC20, piMarket;
  let alice = accounts[0];
  let validator = accounts[1];
  let bob = accounts[2];
  let carl = accounts[3];
  let royaltyReceiver = accounts[3];
  let feeReceiver = '0x7852ef7e88f74138755883fee684abc50af3341e';
  let bidder1 = accounts[5];
  let bidder2 = accounts[6];

  describe("Direct Sale", () => {
    it("should create a piNFT with 500 erc20 tokens to carl", async () => {
      piNFT = await PiNFT.deployed();
      sampleERC20 = await SampleERC20.deployed();
      await sampleERC20.mint(validator, 1000);
      const tx1 = await piNFT.mintNFT(carl, "URI1", [[royaltyReceiver, 500]]);
      const tokenId = tx1.logs[0].args.tokenId.toNumber();
      assert(tokenId === 0, "Failed to mint or wrong token Id");

      await sampleERC20.approve(piNFT.address, 500, { from: validator });
      const tx = await piNFT.addERC20(
        tokenId,
        sampleERC20.address,
        500,
        [[validator, 200]],
        {
          from: validator,
        }
      );

      const tokenBal = await piNFT.viewBalance(tokenId, sampleERC20.address);
      assert(tokenBal == 500, "Failed to add ERC20 tokens into NFT");
    });

    it("should deploy the marketplace contract", async () => {
      piMarket = await PiMarket.deployed();
      assert(piMarket !== undefined, "PiMarket contract was not deployed");
    });

    it("should let carl transfer piNFT to alice", async () => {
      await piNFT.safeTransferFrom(carl, alice, 0, { from: carl });
      assert.equal(await piNFT.ownerOf(0), alice, "Failed to transfer piNFT");
    });

    it("should let alice place piNFT on sale", async () => {
      await piNFT.approve(piMarket.address, 0);
      const result = await piMarket.sellNFT(piNFT.address, 0, 5000);
      assert.equal(
        await piNFT.ownerOf(0),
        piMarket.address,
        "Failed to put piNFT on Sale"
      );
    });

    it("should let bob buy piNFT", async () => {
      let meta = await piMarket._tokenMeta(1);
      assert.equal(meta.status, true);

      let _balance1 = await web3.eth.getBalance(alice);
      let _balance2 = await web3.eth.getBalance(royaltyReceiver);
      let _balance3 = await web3.eth.getBalance(feeReceiver);

      result2 = await piMarket.BuyNFT(1, false, { from: bob, value: 5000 });
      assert.equal(await piNFT.ownerOf(0), bob);

      let balance1 = await web3.eth.getBalance(alice);
      let balance2 = await web3.eth.getBalance(royaltyReceiver);
      let balance3 = await web3.eth.getBalance(feeReceiver);
      let temp = (BigNumber(balance1).minus(BigNumber(_balance1)))
    console.log(balance1, " ",_balance1, " ", temp.toString())
      assert.equal(
        (BigNumber(balance1).minus(BigNumber(_balance1))),
        (460000*100)/10000,
        "Failed to transfer NFT amount"
      );

      assert.equal(
        BigNumber(balance2).minus(BigNumber(_balance2)),
        (5000 * 500) / 10000,
        "Failed to transfer royalty amount"
      );

      // console.log(Number(web3.utils.toBN(balance2)-(web3.utils.toBN(_balance2))))

      console.log(Number(BigNumber(balance3).minus(BigNumber(_balance3))));
      assert.equal(
        BigNumber(balance3).minus(BigNumber(_balance3)),
        (5000 * 100) / 10000,
        "Failed to transfer fee amount"
      );

      meta = await piMarket._tokenMeta(1);
      assert.equal(meta.status, false);
    });

    it("should let bob place piNFT on sale again", async () => {
      await piNFT.approve(piMarket.address, 0, { from: bob });
      const result = await piMarket.sellNFT(piNFT.address, 0, 10000,{
        from: bob,
      });
      assert.equal(
        await piNFT.ownerOf(0),
        piMarket.address,
        "Failed to put piNFT on Sale"
      );
    });

    it("should let bob cancel sale", async () => {
      await piMarket.cancelSale(2, { from: bob });
      meta = await piMarket._tokenMeta(2);
      assert.equal(meta.status, false);
    });

    it("should let bob redeem piNFT", async () => {
      await piNFT.redeemPiNFT(0, alice, validator, sampleERC20.address, 500, {
        from: bob,
      });
      const validatorBal = await sampleERC20.balanceOf(validator);
      assert.equal(
        await piNFT.viewBalance(0, sampleERC20.address),
        0,
        "Failed to remove ERC20 tokens from NFT"
      );
      assert.equal(
        await sampleERC20.balanceOf(validator),
        1000,
        "Failed to transfer ERC20 tokens to validator"
      );
      assert.equal(
        await piNFT.ownerOf(0),
        alice,
        "Failed to transfer NFT to alice"
      );
    });
  });

  describe("Auction sale", () => {
    it("should create a piNFT with 500 erc20 tokens to alice", async () => {
      piNFT = await PiNFT.deployed();
      sampleERC20 = await SampleERC20.deployed();
      piMarket = await PiMarket.deployed();
      await sampleERC20.mint(validator, 1000);
      const tx1 = await piNFT.mintNFT(alice, "URI2", [[royaltyReceiver, 500]]);
      const tokenId = tx1.logs[0].args.tokenId.toNumber();
      assert(tokenId === 1, "Failed to mint or wrong token Id");

      await sampleERC20.approve(piNFT.address, 500, { from: validator });
      const tx = await piNFT.addERC20(
        tokenId,
        sampleERC20.address,
        500,
        [[validator, 200]],
        {
          from: validator,
        }
      );
    });

    it("should let alice place piNFT on auction", async () => {
      await piNFT.approve(piMarket.address, 1);
      const tx = await piMarket.SellNFT_byBid(piNFT.address, 1, 5000, 300);
      assert.equal(
        await piNFT.ownerOf(1),
        piMarket.address,
        "Failed to put piNFT on Auction"
      );
      const result = await piMarket._tokenMeta(3);
      assert.equal(result.bidSale, true);
    });

    it("should let bidders place bid on piNFT", async () => {
      await piMarket.Bid(3, { from: bidder1, value: 6000 });
      await piMarket.Bid(3, { from: bidder2, value: 6500 });
      await piMarket.Bid(3, { from: bidder1, value: 7000 });

      result = await piMarket.Bids(3, 2);
      assert.equal(result.buyerAddress, bidder1);
    });

    it("should let alice execute highest bid", async () => {
      // let _balance1 = await web3.eth.getBalance(alice);
      let _balance2 = await web3.eth.getBalance(royaltyReceiver);
      let _balance3 = await web3.eth.getBalance(feeReceiver);

      await piMarket.executeBidOrder(3, 2, false, { from: alice });
      result = await piNFT.ownerOf(1);
      assert.equal(result, bidder1);

      // let balance1 = await web3.eth.getBalance(alice);
      let balance2 = await web3.eth.getBalance(royaltyReceiver);
      let balance3 = await web3.eth.getBalance(feeReceiver);

      // console.log(BigNumber(balance1).minus(BigNumber(_balance1)));
      // console.log(BigNumber(balance2).minus(BigNumber(_balance2)));
      // console.log(BigNumber(balance3).minus(BigNumber(_balance3)));

      // assert.equal(
      //   BigNumber(balance1).minus(BigNumber(_balance1)),
      //   (7000 * 9400) / 10000,
      //   "Failed to transfer NFT amount"
      // );
      assert.equal(
        BigNumber(balance2).minus(BigNumber(_balance2)),
        (7000 * 500) / 10000,
        "Failed to transfer royalty amount"
      );
      assert.equal(
        BigNumber(balance3).minus(BigNumber(_balance3)),
        (7000 * 100) / 10000,
        "Failed to transfer fee amount"
      );
    });

    it("should let other bidders withdraw their bids", async () => {
      await piMarket.withdrawBidMoney(3, 0, { from: bidder1 });
      await piMarket.withdrawBidMoney(3, 1, { from: bidder2 });
      result = await web3.eth.getBalance(piMarket.address);
      assert.equal(result, 0);
    });

    it("should let bidder disintegrate NFT and ERC20 tokens", async () => {
      await piNFT.redeemPiNFT(1, bob, validator, sampleERC20.address, 500, {
        from: bidder1,
      });
      const validatorBal = await sampleERC20.balanceOf(validator);
      assert.equal(
        await piNFT.viewBalance(1, sampleERC20.address),
        0,
        "Failed to remove ERC20 tokens from NFT"
      );
      assert.equal(
        await sampleERC20.balanceOf(validator),
        2000,
        "Failed to transfer ERC20 tokens to validator"
      );
      assert.equal(
        await piNFT.ownerOf(1),
        bob,
        "Failed to transfer NFT to bob"
      );
    });
  });
  describe("Swap NFTs", () => {
    it("should create a piNFT with 500 erc20 tokens to alice", async () => {
      piNFT = await PiNFT.deployed();
      sampleERC20 = await SampleERC20.deployed();
      piMarket = await PiMarket.deployed();
      await sampleERC20.mint(validator, 1000);
      const tx1 = await piNFT.mintNFT(alice, "URI2", [[royaltyReceiver, 500]]);
      const tokenId = tx1.logs[0].args.tokenId.toNumber();
      assert(tokenId === 2, "Failed to mint or wrong token Id");

      await sampleERC20.approve(piNFT.address, 500, { from: validator });
      const tx = await piNFT.addERC20(
        tokenId,
        sampleERC20.address,
        500,
        [[validator, 200]],
        {
          from: validator,
        }
      );
    });

    it("should create a piNFT with 1000 erc20 tokens to bob", async () => {
      await sampleERC20.mint(validator, 1000);
      const tx1 = await piNFT.mintNFT(bob, "URI2", [[royaltyReceiver, 500]]);
      const tokenId = tx1.logs[0].args.tokenId.toNumber();
      console.log(tokenId);
      assert(tokenId === 3, "Failed to mint or wrong token Id");

      await sampleERC20.approve(piNFT.address, 500, { from: validator });
      const tx = await piNFT.addERC20(
        tokenId,
        sampleERC20.address,
        500,
        [[validator, 200]],
        {
          from: validator,
        }
      );
    });

    it("should let alice initiate swap request", async () => {
      await piNFT.approve(piMarket.address, 2);
      const result = await piMarket.swapTokens(piNFT.address, 2, 3);
      assert.equal(
        await piNFT.ownerOf(2),
        piMarket.address,
        "Failed to put piNFT on Swap"
      );
    });

    it("should let bob accept the swap request", async () => {
      await piNFT.approve(piMarket.address, 3, { from: bob });
      const result = await piMarket.acceptSwap(0, { from: bob });
      assert.equal(
        await piNFT.ownerOf(2),
        bob,
        "Failed to Swap token with Id 2"
      );
      assert.equal(
        await piNFT.ownerOf(3),
        alice,
        "Failed to Swap token with Id 3"
      );
    });

    it("should let alice initiate swap request for token with Id 3", async () => {
      await piNFT.approve(piMarket.address, 3);
      const result = await piMarket.swapTokens(piNFT.address, 3, 2);
      assert.equal(
        await piNFT.ownerOf(3),
        piMarket.address,
        "Failed to put piNFT on Swap"
      );
    });

    it("should let alice cancel swap request", async () => {
      await piMarket.cancelSwap(1);
      swap = await piMarket._swaps(1);
      assert.equal(swap.status, false);
      assert.equal(
        await piNFT.ownerOf(3),
        alice,
        "Failed to cancel Swap request"
      );
    });

    it("should let bob initiate swap request for token with Id 2", async () => {
      await piNFT.approve(piMarket.address, 2, { from: bob });
      const result = await piMarket.swapTokens(piNFT.address, 2, 3, {
        from: bob,
      });
      assert.equal(
        await piNFT.ownerOf(2),
        piMarket.address,
        "Failed to put piNFT on Swap"
      );
    });

    it("should let alice reject swap request", async () => {
      await piMarket.rejectSwap(2);
      swap = await piMarket._swaps(2);
      assert.equal(swap.status, false);
      assert.equal(
        await piNFT.ownerOf(2),
        bob,
        "Failed to reject Swap request"
      );
    });
  });
});