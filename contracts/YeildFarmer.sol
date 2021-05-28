// SPDX-License-Identifier: MIT
pragma solidity ^0.5.7;
pragma experimental ABIEncoderV2;

import "@studydefi/money-legos/dydx/contracts/DydxFlashloanBase.sol";
import "@studydefi/money-legos/dydx/contracts/ICallee.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import './Compuound.sol';

contract YieldFarmer is ICallee, DydxFlashloanBase, Compound {

    // whether we are borrowing or withdrawing
    enum Direction { Deposit, Withdraw } 

    // 
    struct Operation {
        address token;
        address cToken;
        Direction direction;
        uint256 amountProvided;
        uint256 amountBorrowed;
    }

    // set owner
    address public owner;

    // track token and amount
    struct MyCustomData {
        address token;
        uint256 repayAmount;
    }

    constructor() public {
        msg.sender = owner;
    }

    /// @notice function to open position
    /// @param _solo the address of DYDX
    /// @param _token the address of token to borrow
    /// @param _cToken the address of the associated cToken(market we will lend/send collateral)
    /// @param _direction whether we are borrowing or reimbursing money 
    /// @param _amountProvided the amount of the token to provide e.g 30 in diagram flow
    /// @param _amountBorrowed the amount of the token to borrow
    function openPosition
    (
        address _solo, 
        address _token,  
        address _cToken, 
        Direction _direction,
        uint _amountProvided, 
        uint _amountBorrowed
    )
    external 
    {
        require(msg.sender == owner, 'only owner');
        IERC20(_token).transferFrom(msg.sender, address(this), _amountProvided);
        //2 wei is used to pay for flashloan
        _initiateFlashLoan(_solo, _token,_cToken, Direction.Deposit, _amountProvided - 2, _amountBorrowed);
    }




    /// @notice required flashloanCallback function that must be implemented by user and called by Provider
    /// @param _amount the amount of tokens to borrow
    /// @param _token the addrress of the token to borrow
    /// @param _data any bytes data to send 
   function flashloanCallback(uint _amount, address _token, bytes memory _data) override external {
       //do some arbitrage, liquidation, etc..

       //Reimburse borrowed tokens
       IERC20(_token).transfer(msg.sender, _amount);
   }

    /// @notice function required by DYDX postloan ( like the callback required in many flashloans)
    /// @param _sender the address of DYDX
    /// @param _account the address getting the flashloan eg our contract or other we direct funds to
    /// @param _data the operations struct
    // i.e. Encode the logic to handle your flashloaned funds here
    function callFunction
    (
        address sender,
        Account.Info memory account,
        bytes memory data
    ) 

    public 

    {
        // MyCustomData memory mcd = abi.decode(data, (MyCustomData));
        Operation memory operation = abi.decode(data, (Operation));

        // our logic 
         if(operation.direction == Direction.Deposit) {
            supply(operation.cToken, operation.amountProvided + operation.amountBorrowed);
            enterMarket(operation.cToken);
            borrow(operation.cToken, operation.amountBorrowed);
        } else {
            repayBorrow(operation.cToken, operation.amountBorrowed);
            uint cTokenBalance = getcTokenBalance(operation.cToken);
            redeem(operation.cToken, cTokenBalance);
        }

    }

    /// @notice function to start flashloan from DYDX 
    /// @param _solo the address of DYDX
    /// @param _token the address of token to borrow
    /// @param _cToken the address of the associated cToken(market we will lend/send collateral)
    /// @param _direction whether we are borrowing or reimbursing money 
    /// @param _amountProvided the amount of the token to provide e.g 30 in diagram flow
    /// @param _amountBorrowed the amount of the token to borrow
    function _initiateFlashLoan
    (
        address _solo, 
        address _token,  
        address _cToken, 
        Direction _direction,
        uint _amountProvided, 
        uint _amountBorrowed
    )
        internal
    {
        // reference to smart contract of DYDX
        ISoloMargin solo = ISoloMargin(_solo);

        // Get marketId from token address
        uint256 marketId = _getMarketIdFromTokenAddress(_solo, _token);

        // Calculate repay amount (_amount + (2 wei))
        // Approve transfer from
        uint256 repayAmount = _getRepaymentAmountInternal(_amountBorrowed);
        // allow for flashloan reimbursement by approving DYDX contract
        IERC20(_token).approve(_solo, repayAmount);

        // Create operations struct and execute the following steps
        // 1. Withdraw $
        // 2. Call callFunction(...)
        // 3. Deposit back $
        Actions.ActionArgs[] memory operations = new Actions.ActionArgs[](3);

        // 1 withdrawal
        operations[0] = _getWithdrawAction(marketId, _amountBorrowed);
        /* original call action
        operations[1] = _getCallAction(
            // Encode MyCustomData for callFunction
            abi.encode(MyCustomData({token: _token, repayAmount: repayAmount}))
        );
        */
        // 2 call action with compound in mind
        operations[1] = _getCallAction(
            // Encode MyCustomData for callFunction
            abi.encode(Operation({
            token: _token, 
            cToken: _cToken, 
            direction: _direction,
            amountProvided: _amountProvided, 
            amountBorrowed: _amountBorrowed
            }))
        );
        // 3 reimburse the flashloan
        operations[2] = _getDepositAction(marketId, repayAmount);

        Account.Info[] memory accountInfos = new Account.Info[](1);
        accountInfos[0] = _getAccountInfo();

        // DYDX initiates flashloan
        solo.operate(accountInfos, operations);
    }

    
}