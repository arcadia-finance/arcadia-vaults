// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./interfaces/IStable.sol";

/** 
  * @title The reserve fund is used to pay liquidation keepers their liquidation reward, in case the surplus of a vault acution is insufficient.
  * @author Arcadia Finance
 */ 
contract ReserveFund {

  address public owner;
  address public liquidator;

  modifier onlyOwnerOrLiquidator() {
    require(msg.sender == owner || msg.sender == liquidator);
    _;
  }

  modifier onlyOwner() {
    require(msg.sender == owner);
    _;
  }

  constructor () {
    owner = msg.sender;
  }

  /** 
    @notice Sets the liquidator address.
    @dev The liquidator address is used for authentication.
    @param _liquidator the liquidator address.
  */
  function setLiquidator(address _liquidator) external onlyOwner {
    liquidator = _liquidator;
  }


  /**   
    @notice Allows this reserve fund to send rewards to liquidatorkeepers if the surplus of a vaultauction isn't sufficient.
    @dev The protocol treasury to which liquidation rewards have to be sent to, could be this address as well.
    @param amount the amount of tokens to withdraw.
    @param tokenAddress the stable token to transfer.
    @param to self-explanatory.
  */
  function withdraw(uint256 amount, address tokenAddress, address to) external onlyOwnerOrLiquidator returns (bool) {
    require(IStable(tokenAddress).transfer(to, amount), "RF: transfer failed");
    
    return true;
  }
}