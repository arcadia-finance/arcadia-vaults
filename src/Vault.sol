/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "./utils/LogExpMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/ILiquidator.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IRM.sol";
import "./interfaces/IMainRegistry.sol";

/** 
  * @title An Arcadia Vault used to deposit a combination of all kinds of assets
  * @author Arcadia Finance
  * @notice Users can use this vault to deposit assets (ERC20, ERC721, ERC1155, ...). 
            The vault will denominate all the pooled assets into one numeraire (one unit of account, like usd or eth).
            An increase of value of one asset will offset a decrease in value of another asset.
            Users can take out a credit line against the single denominated value.
            Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
  * @dev A vault is a smart contract that will contain multiple assets.
         Using getValue(<numeraire>), the vault returns the combined total value of all (whitelisted) assets the vault contains.
         Integrating this vault as means of collateral management for your own protocol that requires collateral is encouraged.
         Arcadia's vault functions will guarantee you a certain value of the vault.
         For whitelists or liquidation strategies specific to your protocol, contact: dev at arcadia.finance
 */
contract Vault {
    uint256 public constant yearlyBlocks = 2628000;

    /*///////////////////////////////////////////////////////////////
                INTERNAL BOOKKEEPING OF DEPOSITED ASSETS
  ///////////////////////////////////////////////////////////////*/
    address[] public _erc20Stored;
    address[] public _erc721Stored;
    address[] public _erc1155Stored;

    uint256[] public _erc721TokenIds;
    uint256[] public _erc1155TokenIds;

    /*///////////////////////////////////////////////////////////////
                          EXTERNAL CONTRACTS
  ///////////////////////////////////////////////////////////////*/
    address public _registryAddress; /// to be fetched somewhere else?
    address public _stable;
    address public _stakeContract;
    address public _irmAddress;

    // Each vault has a certain 'life', equal to the amount of times the vault is liquidated.
    // Used by the liquidator contract for proceed claims
    uint256 public life;

    address public owner;

    bool public initialized;

    struct debtInfo {
        uint128 _openDebt;
        uint16 _collThres; //2 decimals precision (factor 100)
        uint8 _liqThres; //2 decimals precision (factor 100)
        uint64 _yearlyInterestRate; //18 decimals precision (factor 10**18)
        uint32 _lastBlock;
        uint8 _numeraire;
    }

    debtInfo public debt;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    // set the vault logic implementation to the msg.sender
    // NOTE: this does not represent the owner of the proxy vault!
    //       The owner of this contract (not the derived proxies)
    //       should not have any privilages!
    constructor() {}

    /**
     * @dev Throws if called by any account other than the factory adress.
     */
    modifier onlyFactory() {
        require(
            msg.sender == IMainRegistry(_registryAddress).factoryAddress(),
            "VL: Not factory"
        );
        _;
    }

    /*///////////////////////////////////////////////////////////////
                  REDUCED & MODIFIED OPENZEPPELIN OWNABLE
      Reduced to functions needed, while modified to allow
      a transfer of ownership of this vault by a transfer
      of ownership of the accompanying ERC721 Vault NFT
      issued by the factory. Owner of Vault NFT = owner of vault
  ///////////////////////////////////////////////////////////////*/

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "You are not the owner");
        _;
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public onlyFactory {
        if (newOwner == address(0)) {
            revert("New owner cannot be zero address upon liquidation");
        }
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /**
    @notice Initiates the variables of the vault
    @dev A proxy will be used to interact with the vault logic.
         Therefore everything is initialised through an init function.
         This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
         Costly function (156k gas)
    @param _owner The tx.origin: the sender of the 'createVault' on the factory
    @param registryAddress The 'beacon' contract to which should be looked at for external logic.
    @param stable The contract address of the Arcadia Finance issued stablecoin, pegged to the Numeraire of the vault
    @param stakeContract The stake contract in which stablecoin can be staked. 
                         Used when syncing debt: interest in stable is minted to stakecontract.
    @param irmAddress The contract address of the InterestRateModule, which calculates the interest rate
                      for a credit line, based on the underlying assets.
  */
    function initialize(
        address _owner,
        address registryAddress,
        uint256 numeraire,
        address stable,
        address stakeContract,
        address irmAddress
    ) external payable virtual {
        require(initialized == false);
        _registryAddress = registryAddress;
        owner = _owner;
        debt._collThres = 150;
        debt._liqThres = 110;
        debt._numeraire = uint8(numeraire);
        _stable = stable;
        _stakeContract = stakeContract;
        _irmAddress = irmAddress;

        initialized = true;
    }

    /**
    @notice Deposits assets into the proxy vault by the proxy vault owner.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get deposited. If multiple asset IDs of the same contract address
         are deposited, the assetAddress must be repeated in assetAddresses.
         The ERC20 gets deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
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
    function deposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external payable virtual onlyOwner {
        uint256 assetAddressesLength = assetAddresses.length;

        require(
            assetAddressesLength == assetIds.length &&
                assetAddressesLength == assetAmounts.length &&
                assetAddressesLength == assetTypes.length,
            "Length mismatch"
        );

        require(
            IRegistry(_registryAddress).batchIsWhiteListed(
                assetAddresses,
                assetIds
            ),
            "Not all assets are whitelisted!"
        );

        for (uint256 i; i < assetAddressesLength; ) {
            if (assetTypes[i] == 0) {
                _depositERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _depositERC721(msg.sender, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _depositERC1155(
                    msg.sender,
                    assetAddresses[i],
                    assetIds[i],
                    assetAmounts[i]
                );
            } else {
                require(false, "Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
    @notice Internal function used to deposit ERC20 tokens.
    @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
         After successful transfer, the function checks whether the same asset has been deposited. 
         This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
         If the address has not yet been seen, the ERC20 token address is stored.
    @param _from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC20Address The asset address that should be transferred.
    @param amount The amount of ERC20 tokens to be transferred.
  */
    function _depositERC20(
        address _from,
        address ERC20Address,
        uint256 amount
    ) internal {
        require(
            IERC20(ERC20Address).transferFrom(_from, address(this), amount),
            "Transfer from failed"
        );

        uint256 erc20StoredLength = _erc20Stored.length;
        for (uint256 i; i < erc20StoredLength; ) {
            if (_erc20Stored[i] == ERC20Address) {
                return;
            }
            unchecked {
                ++i;
            }
        }

        _erc20Stored.push(ERC20Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
    }

    /**
    @notice Internal function used to deposit ERC721 tokens.
    @dev Used for all tokens types = 1. Note the transferFrom. No amounts are given since ERC721 are one-off's.
         After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
         This may cause duplicates in the ERC721 stored addresses array, but this is intended. 
    @param _from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC721Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
  */
    function _depositERC721(
        address _from,
        address ERC721Address,
        uint256 id
    ) internal {
        IERC721(ERC721Address).transferFrom(_from, address(this), id);

        _erc721Stored.push(ERC721Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
        _erc721TokenIds.push(id);
    }

    /**
    @notice Internal function used to deposit ERC1155 tokens.
    @dev Used for all tokens types = 2. Note the safeTransferFrom.
         After successful transfer, the function checks whether the combination of address & ID has already been stored.
         If not, the function pushes the new address and ID to the stored arrays.
         This may cause duplicates in the ERC1155 stored addresses array, but this is intended. 
    @param _from The Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC1155Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
    @param amount The amount of ERC1155 tokens to be transferred.
  */
    function _depositERC1155(
        address _from,
        address ERC1155Address,
        uint256 id,
        uint256 amount
    ) internal {
        IERC1155(ERC1155Address).safeTransferFrom(
            _from,
            address(this),
            id,
            amount,
            ""
        );

        bool addrSeen;

        uint256 erc1155StoredLength = _erc1155Stored.length;
        for (uint256 i; i < erc1155StoredLength; ) {
            if (_erc1155Stored[i] == ERC1155Address) {
                if (_erc1155TokenIds[i] == id) {
                    addrSeen = true;
                    break;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (!addrSeen) {
            _erc1155Stored.push(ERC1155Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
            _erc1155TokenIds.push(id);
        }
    }

    /**
    @notice Processes withdrawals of assets by and to the owner of the proxy vault.
    @dev All arrays should be of same length, each index in each array corresponding
         to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
         are to be withdrawn, the assetAddress must be repeated in assetAddresses.
         The ERC20 get withdrawn by transfers. ERC721 & ERC1155 using safeTransferFrom.
         Can only be called by the proxy vault owner.
         Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
         Will fail if "the value after withdrawal / open debt (including unrealised debt) > collateral threshold".
         If no debt is taken yet on this proxy vault, users are free to withraw any asset at any time.
         Example inputs:
            [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
            [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
    @dev After withdrawing assets, the interest rate is renewed
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
    function withdraw(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external payable virtual onlyOwner {
        uint256 assetAddressesLength = assetAddresses.length;

        require(
            assetAddressesLength == assetIds.length &&
                assetAddressesLength == assetAmounts.length &&
                assetAddressesLength == assetTypes.length,
            "Length mismatch"
        );

        for (uint256 i; i < assetAddressesLength; ) {
            if (assetTypes[i] == 0) {
                _withdrawERC20(msg.sender, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _withdrawERC721(msg.sender, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _withdrawERC1155(
                    msg.sender,
                    assetAddresses[i],
                    assetIds[i],
                    assetAmounts[i]
                );
            } else {
                require(false, "Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }

        uint256 openDebt = getOpenDebt();
        if (openDebt != 0) {
            (
                address[] memory _assetAddresses,
                uint256[] memory _assetIds,
                uint256[] memory _assetAmounts
            ) = generateAssetData();
            uint256[] memory valuesPerCreditRating = IRegistry(_registryAddress)
                .getListOfValuesPerCreditRating(
                    _assetAddresses,
                    _assetIds,
                    _assetAmounts,
                    debt._numeraire
                );
            uint256 vaultValue = sumElementsOfList(valuesPerCreditRating);
            uint256 minCollValue;
            //gas: can't overflow: uint129 * uint16 << uint256
            unchecked {
                minCollValue = uint256(openDebt * debt._collThres) / 100;
            }
            require(vaultValue > minCollValue, "V_W: coll. value too low!");

            _setYearlyInterestRate(valuesPerCreditRating, minCollValue);
        }
    }

    /**
    @notice Internal function used to withdraw ERC20 tokens.
    @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
         After successful transfer, the function checks whether the proxy vault has any leftover balance of said asset.
         If not, it will pop() the ERC20 asset address from the stored addresses array.
         Note: this shifts the order of _erc20Stored! 
         This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
    @param to Address the tokens should be sent to. This will in any case be the proxy vault owner
              either being the original user or the liquidator!.
    @param ERC20Address The asset address that should be transferred.
    @param amount The amount of ERC20 tokens to be transferred.
  */
    function _withdrawERC20(
        address to,
        address ERC20Address,
        uint256 amount
    ) internal {
        require(
            IERC20(ERC20Address).transfer(to, amount),
            "Transfer from failed"
        );

        if (IERC20(ERC20Address).balanceOf(address(this)) == 0) {
            uint256 erc20StoredLength = _erc20Stored.length;

            if (erc20StoredLength == 1) {
                // there was only one ERC20 stored on the contract, safe to remove list
                _erc20Stored.pop();
            } else {
                for (uint256 i; i < erc20StoredLength; ) {
                    if (_erc20Stored[i] == ERC20Address) {
                        _erc20Stored[i] = _erc20Stored[erc20StoredLength - 1];
                        _erc20Stored.pop();
                        break;
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }
    }

    /**
    @notice Internal function used to withdraw ERC721 tokens.
    @dev Used for all tokens types = 1. Note the safeTransferFrom. No amounts are given since ERC721 are one-off's.
         After successful transfer, the function checks whether any other ERC721 is deposited in the proxy vault.
         If not, it pops the stored addresses and stored IDs (pop() of two arrs is 180 gas cheaper than deleting).
         If there are, it loops through the stored arrays and searches the ID that's withdrawn, 
         then replaces it with the last index, followed by a pop().
         Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
    @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC721Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
  */
    function _withdrawERC721(
        address to,
        address ERC721Address,
        uint256 id
    ) internal {
        uint256 tokenIdLength = _erc721TokenIds.length;

        if (tokenIdLength == 1) {
            // there was only one ERC721 stored on the contract, safe to remove both lists
            _erc721TokenIds.pop();
            _erc721Stored.pop();
        } else {
            for (uint256 i; i < tokenIdLength; ) {
                if (
                    _erc721TokenIds[i] == id &&
                    _erc721Stored[i] == ERC721Address
                ) {
                    _erc721TokenIds[i] = _erc721TokenIds[tokenIdLength - 1];
                    _erc721TokenIds.pop();
                    _erc721Stored[i] = _erc721Stored[tokenIdLength - 1];
                    _erc721Stored.pop();
                    break;
                }
                unchecked {
                    ++i;
                }
            }
        }

        IERC721(ERC721Address).safeTransferFrom(address(this), to, id);
    }

    /**
    @notice Internal function used to withdraw ERC1155 tokens.
    @dev Used for all tokens types = 2. Note the safeTransferFrom.
         After successful transfer, the function checks whether there is any balance left for that ERC1155.
         If there is, it simply transfers the tokens.
         If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
         If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
         and then replaces it with the last index, followed by a pop().
         Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
    @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
    @param ERC1155Address The asset address that should be transferred.
    @param id The ID of the token to be transferred.
    @param amount The amount of ERC1155 tokens to be transferred.
  */
    function _withdrawERC1155(
        address to,
        address ERC1155Address,
        uint256 id,
        uint256 amount
    ) internal {
        uint256 tokenIdLength = _erc1155TokenIds.length;
        if (
            IERC1155(ERC1155Address).balanceOf(address(this), id) - amount == 0
        ) {
            if (tokenIdLength == 1) {
                _erc1155TokenIds.pop();
                _erc1155Stored.pop();
            } else {
                for (uint256 i; i < tokenIdLength; ) {
                    if (_erc1155TokenIds[i] == id) {
                        if (_erc1155Stored[i] == ERC1155Address) {
                            _erc1155TokenIds[i] = _erc1155TokenIds[
                                tokenIdLength - 1
                            ];
                            _erc1155TokenIds.pop();
                            _erc1155Stored[i] = _erc1155Stored[
                                tokenIdLength - 1
                            ];
                            _erc1155Stored.pop();
                            break;
                        }
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }

        IERC1155(ERC1155Address).safeTransferFrom(
            address(this),
            to,
            id,
            amount,
            ""
        );
    }

    /**
    @notice Generates three arrays about the stored assets in the proxy vault
            in the format needed for vault valuation functions.
    @dev No balances are stored on the contract. Both for gas savings upon deposit and to allow for rebasing/... tokens.
         Loops through the stored asset addresses and fills the arrays. 
         The vault valuation function fetches the asset type through the asset registries.
         There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
    @return assetAddresses An array of asset addresses.
    @return assetIds An array of asset IDs. Will be '0' for ERC20's
    @return assetAmounts An array of the amounts/balances of the asset on the proxy vault. wil be '1' for ERC721's
  */
    function generateAssetData()
        public
        view
        returns (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        )
    {
        uint256 totalLength;
        unchecked {
            totalLength =
                _erc20Stored.length +
                _erc721Stored.length +
                _erc1155Stored.length;
        } //cannot practiaclly overflow. No max(uint256) contracts deployed
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = _erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength; ) {
            cacheAddr = _erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            //assetIds[i] = 0; //gas: no need to store 0, index will continue anyway
            assetAmounts[i] = IERC20(cacheAddr).balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        uint256 j;
        uint256 erc721StoredLength = _erc721Stored.length;
        for (; j < erc721StoredLength; ) {
            cacheAddr = _erc721Stored[j];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = _erc721TokenIds[j];
            assetAmounts[i] = 1;
            unchecked {
                ++i;
            }
            unchecked {
                ++j;
            }
        }

        uint256 k;
        uint256 erc1155StoredLength = _erc1155Stored.length;
        for (; k < erc1155StoredLength; ) {
            cacheAddr = _erc1155Stored[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = _erc1155TokenIds[k];
            assetAmounts[i] = IERC1155(cacheAddr).balanceOf(
                address(this),
                _erc1155TokenIds[k]
            );
            unchecked {
                ++i;
            }
            unchecked {
                ++k;
            }
        }
    }

    /**
    @notice Returns the total value of the vault in a specific numeraire (0 = USD, 1 = ETH, more can be added)
    @dev Fetches all stored assets with their amounts on the proxy vault.
         Using a specified numeraire, fetches the value of all assets on the proxy vault in said numeraire.
    @param numeraire Numeraire to return the value in. For example, 0 (USD) or 1 (ETH).
    @return vaultValue Total value stored on the vault, expressed in numeraire.
  */
    function getValue(uint8 numeraire)
        public
        view
        returns (uint256 vaultValue)
    {
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        ) = generateAssetData();
        vaultValue = IRegistry(_registryAddress).getTotalValue(
            assetAddresses,
            assetIds,
            assetAmounts,
            numeraire
        );
    }

    /**
    @notice Sets the yearly interest rate of the proxy vault, in the form of a 1e18 decimal number.
    @dev First syncs all debt to realise all unrealised debt. Fetches all the asset data and queries the
         Registry to obtain an array of values, split up according to the credit rating of the underlying assets.
  */
    function setYearlyInterestRate() external virtual onlyOwner {
        syncDebt();
        uint256 minCollValue;
        //gas: can't overflow: uint128 * uint16 << uint256
        unchecked {
            minCollValue = (uint256(debt._openDebt) * debt._collThres) / 100;
        }
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        ) = generateAssetData();
        uint256[] memory ValuesPerCreditRating = IRegistry(_registryAddress)
            .getListOfValuesPerCreditRating(
                assetAddresses,
                assetIds,
                assetAmounts,
                debt._numeraire
            );

        _setYearlyInterestRate(ValuesPerCreditRating, minCollValue);
    }

    /**
    @notice Internal function: sets the yearly interest rate (with 18 decimals precision).
    @param valuesPerCreditRating An array of values, split per credit rating.
    @param minCollValue The minimum collateral value based on the amount of open debt on the proxy vault.
  */
    function _setYearlyInterestRate(
        uint256[] memory valuesPerCreditRating,
        uint256 minCollValue
    ) internal {
        debt._yearlyInterestRate = calculateYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );
    }

    /**
    @notice Calculates the yearly interest (with 18 decimals precision).
    @dev Based on an array with values per credit rating (tranches) and the minimum collateral value needed for the debt taken,
         returns the yearly interest rate in a 1e18 decimal number.
    @param valuesPerCreditRating An array of values, split per credit rating.
    @param minCollValue The minimum collateral value based on the amount of open debt on the proxy vault.
    @return yearlyInterestRate The yearly interest rate in a 1e18 decimal number.
  */
    function calculateYearlyInterestRate(
        uint256[] memory valuesPerCreditRating,
        uint256 minCollValue
    ) public view returns (uint64 yearlyInterestRate) {
        yearlyInterestRate = IRM(_irmAddress).getYearlyInterestRate(
            valuesPerCreditRating,
            minCollValue
        );
    }

    // https://twitter.com/0x_beans/status/1502420621250105346
    /**
    @notice Returns the sum of all uints in an array.
    @param _data An uint256 array.
    @return sum The combined sum of uints in the array.
  */
    function sumElementsOfList(uint256[] memory _data)
        public
        payable
        returns (uint256 sum)
    {
        //cache
        uint256 len = _data.length;

        for (uint256 i = 0; i < len; ) {
            // optimizooooor
            assembly {
                sum := add(sum, mload(add(add(_data, 0x20), mul(i, 0x20))))
            }

            unchecked {
                ++i;
            }
        }
    }

    /**
    @notice Syncs all unrealised debt (= interest) on the proxy vault.
    @dev Public function, can be called by any user to keep the game fair and to allow keeps to
         sync the debt before in case a liquidation can be triggered.
         To Find the unrealised debt over an amount of time, you need to calculate D[(1+r)^x-1].
         The base of the exponential: 1 + r, is a 18 decimals fixed point number
         with r the yearly interest rate.
         The exponent of the exponential: x, is a 18 decimals fixed point number.
         The exponent x is calculated as: the amount of blocks since last sync divided by the average of 
         blocks produced over a year (using a 12s average block time).
         Any debt being realised will be accompanied by a mint of stablecoin of equal amounts.
         Bookkeeping requires total open (realised) debt of the system = totalsupply of stablecoin.
         _yearlyInterestRate = 1 + r expressed as 18 decimals fixed point number
  */
    function syncDebt() public {
        uint128 base;
        uint128 exponent;
        uint128 unRealisedDebt;

        unchecked {
            //gas: can't overflow: 1e18 + uint64 <<< uint128
            base = uint128(1e18) + debt._yearlyInterestRate;

            //gas: only overflows when blocks.number > 894262060268226281981748468
            //in practice: assumption that delta of blocks < 341640000 (150 years)
            //as foreseen in LogExpMath lib
            exponent = uint128(
                ((block.number - debt._lastBlock) * 1e18) / yearlyBlocks
            );

            //gas: taking an imaginary worst-case D- tier assets with max interest of 1000%
            //over a period of 5 years
            //this won't overflow as long as opendebt < 3402823669209384912995114146594816
            //which is 3.4 million billion *10**18 decimals

            unRealisedDebt = uint128(
                (debt._openDebt * (LogExpMath.pow(base, exponent) - 1e18)) /
                    1e18
            );
        }

        //gas: could go unchecked as well, but might result in opendebt = 0 on overflow
        debt._openDebt += unRealisedDebt;
        debt._lastBlock = uint32(block.number);

        if (unRealisedDebt > 0) {
            IERC20(_stable).mint(_stakeContract, unRealisedDebt);
        }
    }

    /**
    @notice Can be called by the proxy vault owner to take out (additional) credit against
            his assets stored on the proxy vault.
    @dev amount to be provided in stablecoin decimals. 
    @param amount The amount of credit to take out, in the form of a pegged stablecoin with 18 decimals.
  */
    function takeCredit(uint128 amount) public onlyOwner {
        (
            address[] memory assetAddresses,
            uint256[] memory assetIds,
            uint256[] memory assetAmounts
        ) = generateAssetData();
        _takeCredit(amount, assetAddresses, assetIds, assetAmounts);
    }

    /**
    @notice Internal function to take out credit.
    @dev Syncs debt to cement unrealised debt. 
         MinCollValue is calculated without unrealised debt since it is zero.
         Gets the total value of assets per credit rating.
         Calculates and sets the yearly interest rate based on the values per credit rating and the debt to be taken out.
         Mints stablecoin to the vault owner.
  */
    function _takeCredit(
        uint128 amount,
        address[] memory _assetAddresses,
        uint256[] memory _assetIds,
        uint256[] memory _assetAmounts
    ) internal virtual {
        syncDebt();

        uint256 minCollValue;
        //gas: can't overflow: uint129 * uint16 << uint256
        unchecked {
            minCollValue =
                uint256((uint256(debt._openDebt) + amount) * debt._collThres) /
                100;
        }

        uint256[] memory valuesPerCreditRating = IRegistry(_registryAddress)
            .getListOfValuesPerCreditRating(
                _assetAddresses,
                _assetIds,
                _assetAmounts,
                debt._numeraire
            );
        uint256 vaultValue = sumElementsOfList(valuesPerCreditRating);

        require(
            vaultValue >= minCollValue,
            "Cannot take this amount of extra credit!"
        );

        _setYearlyInterestRate(valuesPerCreditRating, minCollValue);

        //gas: can only overflow when total opendebt is
        //above 340 billion billion *10**18 decimals
        //could go unchecked as well, but might result in opendebt = 0 on overflow
        debt._openDebt += amount;
        IERC20(_stable).mint(owner, amount);
    }

    /**
    @notice Calculates the total open debt on the proxy vault, including unrealised debt.
    @dev Debt is expressed in an uint128 as the stored debt is an uint128 as well.
         _yearlyInterestRate = 1 + r expressed as 18 decimals fixed point number
    @return openDebt Total open debt, as a uint128.
  */
    function getOpenDebt() public view returns (uint128 openDebt) {
        uint128 base;
        uint128 exponent;
        unchecked {
            //gas: can't overflow as long as interest remains < 1744%/yr
            base = uint128(1e18) + debt._yearlyInterestRate;

            //gas: only overflows when blocks.number > ~10**20
            exponent = uint128(
                ((block.number - debt._lastBlock) * 1e18) / yearlyBlocks
            );
        }

        //with sensible blocks, can return an open debt up to 3e38 units
        //gas: could go unchecked as well, but might result in opendebt = 0 on overflow
        openDebt = uint128(
            (debt._openDebt * LogExpMath.pow(base, exponent)) / 1e18
        );
    }

    /**
    @notice Calculates the remaining credit the owner of the proxy vault can take out.
    @dev Returns the remaining credit in the numeraire in which the proxy vault is initialised.
    @return remainingCredit The remaining amount of credit a user can take, 
                            returned in the decimals of the stablecoin.
  */
    function getRemainingCredit()
        public
        view
        returns (uint256 remainingCredit)
    {
        uint256 currentValue = getValue(debt._numeraire);
        uint256 openDebt = getOpenDebt();

        uint256 maxAllowedCredit;
        //gas: cannot overflow unless currentValue is more than
        // 1.15**57 *10**18 decimals, which is too many billions to write out
        unchecked {
            maxAllowedCredit = (currentValue * 100) / debt._collThres;
        }

        //gas: explicit check is done to prevent underflow
        unchecked {
            remainingCredit = maxAllowedCredit > openDebt
                ? maxAllowedCredit - openDebt
                : 0;
        }
    }

    /**
    @notice Function used by owner of the proxy vault to repay any open debt.
    @dev Amount of debt to repay in same decimals as the stablecoin decimals.
         Amount given can be greater than open debt. Will only transfer the required
         amount from the user's balance.
    @param amount Amount of debt to repay.
  */
    function repayDebt(uint256 amount) public virtual onlyOwner {
        syncDebt();

        // if a user wants to pay more than their open debt
        // we should only take the amount that's needed
        // prevents refunds etc
        uint256 openDebt = debt._openDebt;
        uint256 transferAmount = openDebt > amount ? amount : openDebt;
        require(
            IERC20(_stable).transferFrom(
                msg.sender,
                address(this),
                transferAmount
            ),
            "Transfer from failed"
        );

        IERC20(_stable).burn(transferAmount);

        //gas: transferAmount cannot be larger than debt._openDebt,
        //which is a uint128, thus can't underflow
        assert(openDebt >= transferAmount);
        unchecked {
            debt._openDebt -= uint128(transferAmount);
        }

        // if interest is calculated on a fixed rate, set interest to zero if opendebt is zero
        // todo: can be removed safely?
        if (debt._openDebt == 0) {
            debt._yearlyInterestRate = 0;
        }
    }

    /**
    @notice Function called to start a vault liquidation.
    @dev Requires an unhealthy vault (value / debt < liqThres).
         Starts the vault auction on the liquidator contract.
         Increases the life of the vault to indicate a liquidation has happened.
         Sets debtInfo todo: needed?
         Transfers ownership of the proxy vault to the liquidator!
  */
    function liquidateVault(address liquidationKeeper, address liquidator)
        public
        onlyFactory
        returns (bool success)
    {
        //gas: 35 gas cheaper to not take debt into memory
        uint256 totalValue = getValue(debt._numeraire);
        uint256 leftHand;
        uint256 rightHand;

        unchecked {
            //gas: cannot overflow unless totalValue is
            //higher than 1.15 * 10**57 * 10**18 decimals
            leftHand = totalValue * 100;
            //gas: cannot overflow: uint8 * uint128 << uint256
            rightHand = uint256(debt._liqThres) * uint256(debt._openDebt); //yes, double cast is cheaper than no cast (and equal to one cast)
        }

        require(leftHand < rightHand, "This vault is healthy");

        require(
            ILiquidator(liquidator).startAuction(
                address(this),
                life,
                liquidationKeeper,
                owner,
                debt._openDebt,
                debt._liqThres,
                debt._numeraire
            ),
            "Failed to start auction!"
        );

        //gas: good luck overflowing this
        unchecked {
            ++life;
        }

        debt._openDebt = 0;
        debt._lastBlock = 0;

        return true;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    //Function only used for tests
    function getLengths()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            _erc20Stored.length,
            _erc721Stored.length,
            _erc721TokenIds.length,
            _erc1155Stored.length
        );
    }
}
