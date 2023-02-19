# Aconomy Pool Protocol

Any one create Pool and attest lender and borrower to that pool so that they borrower can request loan and other lenders in the pool can fill the loan, if they wish.

## Features

**Create Pool:**
Anyone can create their pool on top of Aconomy PoolRegistry Contract using the below function.

```jsx
    function createPool(
        uint32 _paymentCycleDuration,
        uint32 _paymentDefaultDuration,
        uint32 _loanExpirationTime,
        uint16 _poolFeePercent,
        uint16 _apr,
        string calldata _uri,
        bool _requireLenderAttestation,
        bool _requireBorrowerAttestation
    ) 
```
It will emit a poolCreated event that will return the PoolId and PoolAddress for the Pool.


**Add Lender/Borrower:**
Pool Owner can add lender and borrower for their Pool using the below function.

For Lender
```jsx
    function addlender(
        uint256 _poolId,
        address _lenderAddress,
        uint256 _expirationTime
    ) 
```

For Borrower 
```jsx
    function addBorrower(
        uint256 _poolId,
        address _borrowerAddress,
        uint256 _expirationTime
    ) 
```


**Request Loan:**
Attested Borrower can make requests for loan in the Pool.

```jsx
    function loanRequest(
        address _lendingToken,
        uint256 _poolId,
        uint256 _principal,
        uint32 _duration,
        uint16 _APR,
        address _receiver
    ) public returns (uint256 loanId_)
```

Returns the Loan ID generated.


**Accept Loan:**
Attested Lenders can accept the loans requested in that pool .

```jsx
    function AcceptLoan(uint256 _loanId)
        external
        returns (
            uint256 amountToAconomy,
            uint256 amountToPool,
            uint256 amountToBorrower
        )
```

Returns:
<br />
***uint256 amountToAconomy*** - The aconomy protocol charge.<br />
***uint256 amountToPool*** - The amount that will go to the Pool owner.<br />
***uint256 amountToBorrower*** - The remaining amount will go to the borrower.<br />


**View current amount to repay for Borrower:**
Borrower can check their current amount to repay to loan for healthy credit status.

```jsx
    function viewInstallmentAmount(uint256 _loanId)
        public
        view
        returns (uint256)
```

**View current amount to repay for Borrower:**
Borrower can check their Full amount to be repaid towards the loan after calculating the interest till that moment.

```jsx
    function viewFullRepayAmount(uint256 _loanId)
        public
        view
        returns (uint256)
```

**Repay Loan:**
Borrower should repay their accepted loan per installments .

```jsx
    function repayYourLoan(uint256 _loanId) external
```


**Repay Full Loan:**
Borrower can Fully repay their accepted loan .

```jsx
    function repayFullLoan(uint256 _loanId) external
```


## FundingPool functions

**Supply to Pool:**
Attested Lenders can bid for supply to pool after checking the APR and other information of that pool address.
This function is called in deployPool contract in the address that is returned during createPool.

```jsx
    function supplyToPool(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _amount,
        uint32 _maxLoanDuration,
        uint16 _interestRate,
        uint256 _expiration
    ) external 
```

The function will emit a event that will return a BidId:
```jsx
 event SupplyToPool(
        address indexed lender,
        uint256 indexed poolId,
        uint256 BidId,
        address indexed ERC20Token,
        uint256 tokenAmount
    );
```


**Accept Bid:**
Pool Owner can accept the bid for getting funding in that pool .

```jsx
    function AcceptBid(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender,
        address _receiver
    ) external
```

It will emit a event which has the payment to do per cycle.

```jsx
event AcceptedBid(
        address reciever,
        uint256 BidId,
        uint256 PoolId,
        uint256 Amount,
        uint256 paymentCycleAmount
    )
```


**View current amount to repay for Pool Owner:**
Pool Owner can check their current amount to repay to the funding given to their pool, for healthy credit status.

```jsx
    function viewInstallmentAmount(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) public view returns (uint256)
```


**View Full amount to repay for Pool Owner:**
Pool Owner can check their full amount to repay to the funding given to their pool, for healthy credit status.

```jsx
    function viewFullRepayAmount(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) public view returns (uint256)
```

**Repay Funding amount per cycle:**
Pool Owner should repay their accepted loan per cycle .

```jsx
    function RepayInstallment(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) external
```


**Repay Funding amount Full:**
Pool Owner can repay the full amount .

```jsx
    function RepayFullAmount(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) external
```


**Withdraw Bid:**
Lender can withdraw their bid after expiration time is over .

```jsx
    function Withdraw(
        uint256 _poolId,
        address _ERC20Address,
        uint256 _bidId,
        address _lender
    ) external
```
