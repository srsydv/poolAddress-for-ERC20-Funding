// const FundingPool = artifacts.require("FundingPool");
// const PoolRegistry = artifacts.require("PoolRegistry");
// const IERC20 = artifacts.require("IERC20");

// contract("FundingPool", (accounts) => {
//   let fundingPool;
//   let poolRegistry;
//   let erc20Token;

//   const poolOwner = accounts[0];
//   const lender = accounts[1];
//   const nonLender = accounts[2];
//   const receiver = accounts[3];

//   const paymentCycleDuration = 30;
//   const paymentDefaultDuration = 7;
//   const feePercent = 1;

//   const poolId = 1;
//   const erc20Amount = 1000;
//   const maxLoanDuration = 90;
//   const interestRate = 10;
//   const expiration = Math.floor(Date.now() / 1000) + 3600; // expires in an hour

//   before(async () => {
//     poolRegistry = await PoolRegistry.new();
//     erc20Token = await IERC20.new("TestToken", "TST", 18, erc20Amount, {
//       from: poolOwner,
//     });
//     fundingPool = await FundingPool.new(
//       poolOwner,
//       poolRegistry.address,
//       paymentCycleDuration,
//       paymentDefaultDuration,
//       feePercent,
//       { from: poolOwner }
//     );
//     await poolRegistry.addPool(poolId, fundingPool.address, poolOwner, {
//       from: poolOwner,
//     });
//     await poolRegistry.verifyLender(poolId, lender, { from: poolOwner });
//   });

//   describe("supplyToPool()", () => {
//     it("should allow lender to supply funds to the pool", async () => {
//       await erc20Token.approve(fundingPool.address, erc20Amount, {
//         from: lender,
//       });
//       const tx = await fundingPool.supplyToPool(
//         poolId,
//         erc20Token.address,
//         erc20Amount,
//         maxLoanDuration,
//         interestRate,
//         expiration,
//         { from: lender }
//       );

//       const bidId = tx.logs[0].args.BidId.toNumber();
//       const fundDetail = await fundingPool.lenderPoolFundDetails(
//         lender,
//         poolId,
//         erc20Token.address,
//         bidId
//       );

//       assert.equal(fundDetail.amount, erc20Amount);
//       assert.equal(fundDetail.maxDuration, maxLoanDuration);
//       assert.equal(fundDetail.interestRate, interestRate);
//       assert.equal(fundDetail.expiration, expiration);
//       assert.equal(fundDetail.state, 0); // BidState.PENDING
//     });

//     it("should not allow non-lender to supply funds to the pool", async () => {
//       await erc20Token.approve(fundingPool.address, erc20Amount, {
//         from: lender,
//       });
//       await truffleAssert.reverts(
//         fundingPool.supplyToPool(
//           poolId,
//           erc20Token.address,
//           erc20Amount,
//           maxLoanDuration,
//           interestRate,
//           expiration,
//           { from: nonLender }
//         ),
//         "Not verified lender"
//       );
//     });
//   });
// });
// //   describe("AcceptBid()", () => {
// //     let bidId;

// //     before(async () => {
// //       await erc20Token.approve(fundingPool.address, erc20Amount, {
// //         from: lender,
// //       });
// //       const tx = await fundingPool.supplyToPool(
// //         poolId,
// //         erc20Token.address,
// //         erc20Amount,
// //         maxLoanDuration,
// //         interestRate,
// //         expiration,