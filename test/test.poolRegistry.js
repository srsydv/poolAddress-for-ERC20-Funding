var BigNumber = require('big-number');
var moment = require('moment');
const { BN, constants, expectEvent, shouldFail, time, expectRevert } = require('@openzeppelin/test-helpers');
const PoolRegistry = artifacts.require("poolRegistry");
const AttestRegistry = artifacts.require("AttestationRegistry")
const AttestServices = artifacts.require("AttestationServices");
const AconomyFee = artifacts.require("AconomyFee")
const PoolAddress = artifacts.require('poolAddress')
const lendingToken = artifacts.require('mintToken')
const poolAddress = artifacts.require("poolAddress")


contract("poolRegistry", async (accounts) => {

const paymentCycleDuration = moment.duration(30, 'days').asSeconds()
const loanDuration = moment.duration(150, 'days').asSeconds()
const loanDefaultDuration = moment.duration(90, 'days').asSeconds()
const loanExpirationDuration = moment.duration(180, 'days').asSeconds()

const expirationTime = BigNumber(moment.now()).add(
    moment.duration(30, 'days').seconds())
  

let aconomyFee, poolRegis, attestRegistry, attestServices, res, poolId1, pool1Address,poolId2,  loanId1, poolAddressInstance, erc20;

    it("should set Aconomyfee", async () => {
        aconomyFee = await AconomyFee.deployed();
       await aconomyFee.setProtocolFee(200);
        let protocolFee = await aconomyFee.protocolFee()
        let aconomyFeeOwner = await aconomyFee.getAconomyOwnerAddress()
        assert.equal(aconomyFeeOwner, accounts[0], "wrong Aconomy fee owner")
        assert.equal(protocolFee.toNumber(), 200, "Wrong set Protocol Fee")
    })

    it("should create attestRegistry, attestationService", async () => {
        // attestRegistry = await AttestRegistry.deployed();
        // assert.notEqual(attestRegistry.address, null, "address is zero");
        attestServices = await AttestServices.deployed();
        assert.notEqual(attestServices.address, null||undefined, "Attestation Services unable to deployed")
    });


    it("should create Pool", async() => {
        // console.log("attestTegistry: ", attestServices.address)
        poolRegis = await PoolRegistry.deployed()
       res =  await poolRegis.createPool(
            paymentCycleDuration,
            loanDefaultDuration,
            loanExpirationDuration,
            100,
            1000,
            "sk.com",
            true,
            true
        );
        poolId1 = res.logs[6].args.poolId.toNumber()
        console.log(poolId1, "poolId1")
        pool1Address = res.logs[4].args.poolAddress;
        console.log(pool1Address, "poolAdress")

        // res =  await poolRegis.createPool(
        //     accounts[0],
        //     paymentCycleDuration,
        //     loanDefaultDuration,
        //     loanExpirationDuration,
        //     10,
        //     true,
        //     true,
        //     "skk.com"
        // );
        
        // poolId2 = res.logs[0].args.poolId.toNumber()


    })


    it("should add Lender to the pool", async() => {
        res = await poolRegis.lenderVerification(poolId1, accounts[0])
        assert.equal(res.isVerified_, false, "AddLender function not called but verified")
       await poolRegis.addLender(poolId1, accounts[0], expirationTime, {from: accounts[0]} )
        res = await poolRegis.lenderVerification(poolId1, accounts[0])
        assert.equal(res.isVerified_, true, "Lender Not added to pool, lenderVerification failed")
    })

    it("should add Borrower to the pool", async() => {
        
         await poolRegis.addBorrower(poolId1, accounts[1], expirationTime, {from: accounts[0]} )
         res = await poolRegis.borrowerVerification(poolId1, accounts[1])
        assert.equal(res.isVerified_, true, "Borrower Not added to pool, borrowerVerification failed")
    })

    it("should allow Attested Borrower to Request Loan in a Pool", async() => {

         erc20 = await lendingToken.deployed()
         await erc20.mint(accounts[0], 10000000000)
        // poolAddressInstance = await PoolAddress.at(pool1Address)
        poolAddressInstance = await poolAddress.deployed()
        // console.log(poolAddressInstance)

       res = await poolAddressInstance.loanRequest(
        erc20.address,
        poolId1,
        1000000000,
        loanDuration,
       1000,
        accounts[1],
        {from: accounts[1]}
       )
    // console.log(res.logs[0].args)
       loanId1 = res.logs[0].args.loanId.toNumber()
     let paymentCycleAmount = res.logs[0].args.paymentCycleAmount.toNumber()

    //  let res2 = await poolAddressInstance.calculateNextDueDate(loanId1)
    //  console.log(res2.toNumber())
     console.log(paymentCycleAmount, "pca")
     assert.equal(loanId1, 0, "Unable to create loan: Wrong LoanId")

     //pool2
    //  res= await poolAddressInstance.loanRequest(
    //     erc20.address,
    //     poolId1,
    //     1000,
    //     loanDefaultDuration,
    //     BigNumber(1, 2),
    //     accounts[1],
    //     {from: accounts[1]}
    //    )
    //    console.log(loanId1, "loanid1")
    //    console.log(res.logs[0].args.loanId.toNumber(), "loanid2")
    })

    it("should Accept loan ", async() => {
        await erc20.approve(poolAddressInstance.address, 1000000000)
        let _balance1 = await erc20.balanceOf(accounts[0]);
        // console.log(_balance1.toNumber())
        res = await poolAddressInstance.AcceptLoan(loanId1, {from:accounts[0]})
        _balance1 = await erc20.balanceOf(accounts[1]);
// console.log(_balance1.toNumber())
        //Amount that the borrower will get is 979 after cutting fees and market charges
        // assert.equal(_balance1.toNumber(), 979, "Not able to accept loan");
    })

    it("anyone can repay Loan ", async() => {
        // await erc20.transfer(accounts[1], 12000, {from: accounts[0]})
        // console.log((await time.latest()).toNumber())
        // console.log((await poolAddressInstance.calculateNextDueDate(loanId1)).toNumber())
        
        //First Installment
        await time.increase(paymentCycleDuration+1)
        // console.log((await poolAddressInstance.viewInstallmentAmount(loanId1)).toNumber()) 
        await erc20.approve(poolAddressInstance.address, 205000000, {from:accounts[0]})
        res = await poolAddressInstance.repayYourLoan(loanId1, {from: accounts[0]})
        console.log(res.logs[0].args.Amount.toNumber())
        
        //Second installment
        await time.increase(paymentCycleDuration+1)
        await erc20.approve(poolAddressInstance.address, 205000000, {from:accounts[1]})
        res = await poolAddressInstance.repayYourLoan(loanId1, {from: accounts[1]})
        console.log(res.logs[0].args.Amount.toNumber())
       
        
        //Full loan Repay
        await erc20.approve(poolAddressInstance.address, 700000000, {from:accounts[0]})
        res = await poolAddressInstance.repayFullLoan(loanId1, {from: accounts[0]})
        console.log(res.logs[0].args.Amount.toNumber())

        //Full loan repaid, should revert.
        await time.increase(paymentCycleDuration+1)
        
        assert((await poolAddressInstance.viewFullRepayAmount(loanId1)).toNumber()==0, "Loan not fully repaid, viewFullRepayment")
        await erc20.approve(poolAddressInstance.address, 205000000, {from:accounts[0]})
       await expectRevert(poolAddressInstance.repayYourLoan(loanId1, {from: accounts[0]}), "Loan must be accepted")


    })

//     it("should repay some amount of lone ", async() => {
//          // Approve loan amount and transfer it to the borrower
//   await erc20.approve(poolAddressInstance.address, 500, { from: accounts[1] });
//   await poolAddressInstance.borrow(500, { from: accounts[2] });
  
//   // Check loan status before repayment
//   let loanBefore = await poolAddressInstance.loans(loanId1);
//   assert.equal(loanBefore.status, "active", "Loan status should be active before repayment");
  
//   // Repay full loan amount
//   await erc20.approve(poolAddressInstance.address, loanAmount, { from: borrower });
//   await poolAddressInstance.repayYourLoan(loanId1, { from: borrower });
  
//   // Check loan status after repayment
//   let loanAfter = await poolAddressInstance.loans(loanId1);
//   assert.equal(loanAfter.status, "repaid", "Loan status should be repaid after full repayment");
//     })


})
