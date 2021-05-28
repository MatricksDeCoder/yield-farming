// SPDX-License-Identifier: MIT
pragma solidity ^0.5.7;
interface IComptroller {
    // enterMarket indicate which token you want to use as collateral
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory); // need to enter market before borrowi
    function claimComp(address holder) external; // claim COMP token as a participant
    function getCompAddress() external view returns(address); // address of COMP Token
}


  