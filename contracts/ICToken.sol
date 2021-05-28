// SPDX-License-Identifier: MIT
pragma solidity ^0.5.7;

interface ICToken {
  function mint(uint mintAmount) external returns (uint); // lend to protocol
  function redeem(uint redeemTokens) external returns (uint); // get lent money back
  function borrow(uint borrowAmount) external returns (uint); // borrow money 
  function repayBorrow(uint repayAmount) external returns (uint); // repay borrowed money
  function borrowBalanceCurrent(address account) external returns (uint); // amount borrowed + interest
  function balanceOf(address owner) external view returns (uint); // balance of cToken that you own
  function underlying() external view returns(address); // address of cToken market underlying
}
