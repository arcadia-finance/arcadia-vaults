// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../Vault.sol";
import {FixedPointMathLib} from './../utils/FixedPointMathLib.sol';

contract VaultPaperTrading is Vault {
  using FixedPointMathLib for uint256;

  address public _tokenShop;

  constructor() {
    owner = msg.sender;
  }


  /**
   * @dev Throws if called by any address other than the tokenshop
   *  only added for the paper trading competition
   */
  modifier onlyTokenShop() {
    require(msg.sender == _tokenShop, "Not tokenshop");
    _;
  }

  function initialize(address, address, address, address, address) external payable override {
   revert('Not Allowed');
  }

  /** 
    @notice Initiates the variables of the vault
    @dev A proxy will be used to interact with the vault logic.
         Therefore everything is initialised through an init function.
         This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
         Costly function (156k gas)
    @param _owner The tx.origin: the sender of the 'createVault' on the factory
    @param registryAddress The 'beacon' contract to which should be looked at for external logic.
    @param stable The contract address of the stablecoin of Arcadia Finance
    @param stakeContract The stake contract in which stablecoin can be staked. 
                         Used when syncing debt: interest in stable is minted to stakecontract.
    @param irmAddress The contract address of the InterestRateModule, which calculates the going interest rate
                      for a credit line, based on the underlying assets.
    @param tokenShop The contract with the mocked token shop, added for the paper trading competition
  */
  function initialize(address _owner, address registryAddress, address stable, address stakeContract, address irmAddress, address tokenShop) external payable {
    require(initialized == false);
    _registryAddress = registryAddress;
    owner = _owner;
    debt._collThres = 150;
    debt._liqThres = 110;
    _stable = stable;
    _stakeContract = stakeContract;
    _irmAddress = irmAddress;
    _tokenShop = tokenShop; //Variable only added for the paper trading competition

    initialized = true;

    //Following logic added only for the paper trading competition
    //All new vaults are initiated with $1.000.000
    address[] memory addressArr = new address[](1);
    uint256[] memory idArr = new uint256[](1);
    uint256[] memory amountArr = new uint256[](1);

    addressArr[0] = _stable;
    idArr[0] = 0;
    amountArr[0] = FixedPointMathLib.WAD;

    uint256 rateStableToUsd = IRegistry(_registryAddress).getTotalValue(addressArr, idArr, amountArr, 0);
    uint256 stableAmount = FixedPointMathLib.mulDivUp(1000000 * FixedPointMathLib.WAD, FixedPointMathLib.WAD, rateStableToUsd);
    IERC20(_stable).mint(address(this), stableAmount);
    super._depositERC20(address(this), _stable, stableAmount);
  }

  /** 
    @notice The function used to deposit assets into the proxy vault by the proxy vault owner.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get deposited. If multiple asset IDs of the same contract address
         are deposited, the assetAddress must be repeated in assetAddresses.
         The ERC20 get deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner to avoid attacks where malicous actors can deposit 1 wei assets,
         increasing gas costs upon credit issuance and withrawals.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be deposited one address,
                          even if multiple assets of the same contract address are deposited.
    @param assetIds The asset IDs that will be deposited for ERC721 & ERC1155. 
                    When depositing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be deposited. 
    @param assetTypes The types of the assets to be deposited.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable override onlyTokenShop {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");
    

    require(IRegistry(_registryAddress).batchIsWhiteListed(assetAddresses, assetIds), "Not all assets are whitelisted!");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        super._depositERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        super._depositERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        super._depositERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

  }

  /** 
    @notice Processes withdrawals of assets by and to the owner of the proxy vault.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
         are to be withdrawn, the assetAddress must be repeated in assetAddresses.
         The ERC20 get withdrawn by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner.
         Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
         Will fail if "the value after withdrawal / open debt (including unrealised debt) > collateral threshold".
         If no debt is taken yet on this proxy vault, users are free to withraw any asset at any time.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @param assetAddresses The contract addresses of the asset. For each asset to be withdrawn one address,
                          even if multiple assets of the same contract address are withdrawn.
    @param assetIds The asset IDs that will be withdrawn for ERC721 & ERC1155. 
                    When withdrawing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
    @param assetAmounts The amounts of the assets to be withdrawn. 
    @param assetTypes The types of the assets to be withdrawn.
                      0 = ERC20
                      1 = ERC721
                      2 = ERC1155
                      Any other number = failed tx
  */
  function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts, uint256[] calldata assetTypes) external payable override onlyTokenShop {
    uint256 assetAddressesLength = assetAddresses.length;

    require(assetAddressesLength == assetIds.length &&
             assetAddressesLength == assetAmounts.length &&
             assetAddressesLength == assetTypes.length, "Length mismatch");

    for (uint256 i; i < assetAddressesLength;) {
      if (assetTypes[i] == 0) {
        super._withdrawERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
      }
      else if (assetTypes[i] == 1) {
        super._withdrawERC721(msg.sender, assetAddresses[i], assetIds[i]);
      }
      else if (assetTypes[i] == 2) {
        super._withdrawERC1155(msg.sender, assetAddresses[i], assetIds[i], assetAmounts[i]);
      }
      else {
        require(false, "Unknown asset type");
      }
      unchecked {++i;}
    }

    uint256 openDebt = getOpenDebt();
    if (openDebt != 0) {
      require((getValue(debt._numeraire) * 100 / openDebt) > debt._collThres , "Cannot withdraw since the collateral value would become too low!" );
    }

  }

}