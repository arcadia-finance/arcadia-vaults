/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import "./utils/LogExpMath.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IERC721.sol";
import "./interfaces/IERC1155.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/ILiquidator.sol";
import "./interfaces/IRegistry.sol";
import "./interfaces/IMainRegistry.sol";
import "./interfaces/ILendingPool.sol";
import "./interfaces/ITrustedCreditor.sol";
import "./interfaces/IActionBase.sol";
import {ActionData} from "./actions/utils/ActionData.sol";

/**
 * @title An Arcadia Vault used to deposit a combination of all kinds of assets
 * @author Arcadia Finance
 * @notice Users can use this vault to deposit assets (ERC20, ERC721, ERC1155, ...).
 * The vault will denominate all the pooled assets into one baseCurrency (one unit of account, like usd or eth).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Users can take out a credit line against the single denominated value.
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev A vault is a smart contract that will contain multiple assets.
 * Using getValue(<baseCurrency>), the vault returns the combined total value of all (whitelisted) assets the vault contains.
 * Integrating this vault as means of collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's vault functions will guarantee you a certain value of the vault.
 * For whitelists or liquidation strategies specific to your protocol, contact: dev at arcadia.finance
 */
contract Vault {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    bool public isTrustedCreditorSet;

    uint16 public vaultVersion;

    address public liquidator;
    address public owner;
    address public registry;
    address public trustedCreditor;
    address public baseCurrency;

    address[] public erc20Stored;
    address[] public erc721Stored;
    address[] public erc1155Stored;

    uint256[] public erc721TokenIds;
    uint256[] public erc1155TokenIds;

    mapping(address => bool) public allowed;
    mapping(address => bool) public isAssetManager;

    struct AddressSlot {
        address value;
    }

    event Upgraded(address indexed implementation);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Throws if called by any account other than the factory adress.
     */
    modifier onlyFactory() {
        require(msg.sender == IMainRegistry(registry).factoryAddress(), "V: You are not the factory");
        _;
    }

    /**
     * @dev Throws if called by any account other than an authorised adress.
     */
    modifier onlyAuthorized() {
        require(allowed[msg.sender], "V: You are not authorized");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "V: You are not the owner");
        _;
    }

    /**
     * @dev Throws if called by any account other than an asset manager.
     */
    modifier onlyAssetManager() {
        require(isAssetManager[msg.sender], "V: You are not an asset manager");
        _;
    }

    constructor() {}

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the variables of the vault
     * @dev A proxy will be used to interact with the vault logic.
     * Therefore everything is initialised through an init function.
     * This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
     * Costly function (156k gas)
     * @param owner_ The tx.origin: the sender of the 'createVault' on the factory
     * @param registry_ The 'beacon' contract to which should be looked at for external logic.
     * @param vaultVersion_ The version of the vault logic.
     */
    function initialize(address owner_, address registry_, uint16 vaultVersion_) external {
        require(vaultVersion == 0, "V_I: Already initialized!");
        require(vaultVersion_ != 0, "V_I: Invalid vault version");
        owner = owner_;
        registry = registry_;
        vaultVersion = vaultVersion_;
        isAssetManager[owner_] = true;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot & updates the vault version.
     */
    function upgradeVault(address newImplementation, uint16 newVersion) external onlyFactory {
        vaultVersion = newVersion;
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;

        emit Upgraded(newImplementation);
    }

    /**
     * @dev Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner via the factory.
     * A transfer of ownership of this vault by a transfer
     * of ownership of the accompanying ERC721 Vault NFT
     * issued by the factory. Owner of Vault NFT = owner of vault
     */
    function transferOwnership(address newOwner) public onlyFactory {
        if (newOwner == address(0)) {
            revert("V_TO: INVALID_RECIPIENT");
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

    /* ///////////////////////////////////////////////////////////////
                        BASE CURRENCY LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the baseCurrency of a vault.
     * @param baseCurrency_ the new baseCurrency for the vault.
     */
    function setBaseCurrency(address baseCurrency_) public onlyAuthorized {
        _setBaseCurrency(baseCurrency_);
    }

    /**
     * @notice Internal function: sets baseCurrency.
     * @param baseCurrency_ the new baseCurrency for the vault.
     * @dev First checks if there is no locked value. If there is no value locked then the baseCurrency gets changed to the param
     */
    function _setBaseCurrency(address baseCurrency_) private {
        require(getUsedMargin() == 0, "V_SBC: Can't change baseCurrency when Used Margin > 0");
        require(IMainRegistry(registry).isBaseCurrency(baseCurrency_), "V_SBC: baseCurrency not found");
        baseCurrency = baseCurrency_; //Change this to where ever it is going to be actually set
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates a margin account on the vault for one trusted application..
     * @param protocol The contract address of the trusted application.
     * @dev The open position is fetched at a contract of the application -> only allow trusted audited protocols!!!
     * @dev Currently only one trusted protocol can be set.
     * @dev Only open margin accounts for protocols you trust!
     * The protocol has significant authorisation: use margin (-> trigger liquidation)
     */
    function openTrustedMarginAccount(address protocol) public onlyOwner {
        require(!isTrustedCreditorSet, "V_OMA: ALREADY SET");
        //ToDo: Check in Factory/Mainregistry if protocol is indeed trusted?

        (bool success, address baseCurrency_, address liquidator_) =
            ITrustedCreditor(protocol).openMarginAccount(vaultVersion);
        require(success, "V_OMA: OPENING ACCOUNT REVERTED");

        liquidator = liquidator_;
        trustedCreditor = protocol;
        if (baseCurrency != baseCurrency_) {
            _setBaseCurrency(baseCurrency_);
        }
        isTrustedCreditorSet = true;
        allowed[protocol] = true;
    }

    /**
     * @notice Closes the margin account on the vault of the trusted application..
     * @dev The open position is fetched at a contract of the application -> only allow trusted audited protocols!!!
     * @dev Currently only one trusted protocol can be set.
     */
    function closeTrustedMarginAccount() public onlyOwner {
        require(isTrustedCreditorSet, "V_CMA: NOT SET");
        require(ITrustedCreditor(trustedCreditor).getOpenPosition(address(this)) == 0, "V_CMA: NON-ZERO OPEN POSITION");

        isTrustedCreditorSet = false;
        allowed[trustedCreditor] = false;
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Can be called by authorised applications to increase a margin position.
     * @param baseCurrency_ The Base-currency in which the margin position is denominated
     * @param amount The amount the position is increased.
     * @return success Boolean indicating if there is sufficient free margin to increase the margin position
     */
    function increaseMarginPosition(address baseCurrency_, uint256 amount)
        public
        view
        onlyAuthorized
        returns (bool success)
    {
        if (baseCurrency_ != baseCurrency) {
            return false;
        }

        // Check that the collateral value is bigger than the sum  of the already used margin and the increase
        // ToDo: For trusted protocols, already pass usedMargin with the call -> avoid additional hop back to trusted protocol to fetch already open debt
        success = getCollateralValue() >= getUsedMargin() + amount;
    }

    /**
     * @notice Returns the total value of the vault in a specific baseCurrency
     * @dev Fetches all stored assets with their amounts on the proxy vault.
     * Using a specified baseCurrency, fetches the value of all assets on the proxy vault in said baseCurrency.
     * @param baseCurrency_ The asset to return the value in.
     * @return vaultValue Total value stored on the vault, expressed in baseCurrency.
     */
    function getVaultValue(address baseCurrency_) public view returns (uint256 vaultValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        vaultValue = IRegistry(registry).getTotalValue(assetAddresses, assetIds, assetAmounts, baseCurrency_);
    }

    /**
     * @notice Calculates the total collateral value of the vault.
     * @return collateralValue The collateral value, returned in the decimals of the base currency.
     * @dev Returns the value denominated in the baseCurrency in which the proxy vault is initialised.
     * @dev The collateral value of the vault is equal to the spot value of the underlying assets,
     * discounted by a haircut (the collateral factor). Since the value of
     * collateralised assets can fluctuate, the haircut guarantees that the vault
     * remains over-collateralised with a high confidence level (99,9%+). The size of the
     * haircut depends on the underlying risk of the assets in the vault, the bigger the volatility
     * or the smaller the on-chain liquidity, the bigger the haircut will be.
     */
    function getCollateralValue() public view returns (uint256 collateralValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        collateralValue = IRegistry(registry).getCollateralValue(assetAddresses, assetIds, assetAmounts, baseCurrency);
    }

    /**
     * @notice Calculates the total liquidation value of the vault.
     * @return liquidationValue The liquidation value, returned in the decimals of the base currency.
     * @dev Returns the value denominated in the baseCurrency in which the proxy vault is initialised.
     * @dev The liquidation value of the vault is equal to the spot value of the underlying assets,
     * discounted by a haircut (the liquidation factor).
     * The liquidation value takes into account that not the full value of the assets can go towards
     * repaying the debt, but only a fraction of it, the remaining value is lost due to:
     * slippage while liquidating the assets, fees for the auction initiator, gas fees and
     * a penalty to the protocol.
     */
    function getLiquidationValue() public view returns (uint256 liquidationValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        liquidationValue = IRegistry(registry).getLiquidationValue(assetAddresses, assetIds, assetAmounts, baseCurrency);
    }

    /**
     * @notice Returns the used margin of the proxy vault.
     * @return usedMargin The used amount of margin a user has taken
     * @dev The used margin is denominated in the baseCurrency of the proxy vault.
     * @dev Currently only one trusted application (Arcadia Lending) can open a margin account.
     * The open position is fetched at a contract of the application -> only allow trusted audited protocols!!!
     */
    function getUsedMargin() public view returns (uint256 usedMargin) {
        if (!isTrustedCreditorSet) return 0;

        usedMargin = ITrustedCreditor(trustedCreditor).getOpenPosition(address(this));
    }

    /**
     * @notice Calculates the remaining margin the owner of the proxy vault can use.
     * @return freeMargin The remaining amount of margin a user can take.
     * @dev The free margin is denominated in the baseCurrency of the proxy vault,
     * with an equal number of decimals as the base currency.
     */
    function getFreeMargin() public view returns (uint256 freeMargin) {
        uint256 collateralValue = getCollateralValue();
        uint256 usedMargin = getUsedMargin();

        //gas: explicit check is done to prevent underflow
        unchecked {
            freeMargin = collateralValue > usedMargin ? collateralValue - usedMargin : 0;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                          LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Function called to start a vault liquidation.
     * @dev Requires an unhealthy vault (value / debt < liqThres).
     * Starts the vault auction on the liquidator contract.
     * Increases the life of the vault to indicate a liquidation has happened.
     * Transfers ownership of the proxy vault to the liquidator!
     * @param liquidationInitiator Address of the keeper who initiated the liquidation process.
     * @dev trustedCreditor is a trusted contract.
     * @dev After an auction is successfully started, interest acrual should stop.
     * This must be implemented by trustedCreditor
     * @dev If liquidateVault(address) is successfull, Factory will transfer ownership of the Vault to the Liquidator.
     */
    function liquidateVault(address liquidationInitiator) public onlyFactory returns (address liquidator_) {
        uint256 usedMargin = getUsedMargin();

        require(getLiquidationValue() < usedMargin, "V_LV: This vault is healthy");

        //Start the liquidation process
        ILiquidator(liquidator).startAuction(
            liquidationInitiator, owner, uint128(usedMargin), baseCurrency, trustedCreditor
        );

        //Hook implemented on the trusted creditor contract to notify that the vault
        //is being liquidated and trigger any necessary logic on the trustedCreditor.
        ITrustedCreditor(trustedCreditor).liquidateVault(usedMargin);

        liquidator_ = liquidator;
    }

    /* ///////////////////////////////////////////////////////////////
                    ASSET DEPOSIT/WITHDRAWN LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Deposits assets into the proxy vault by the proxy vault owner.
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get deposited. If multiple asset IDs of the same contract address
     * are deposited, the assetAddress must be repeated in assetAddresses.
     * The ERC20 gets deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
     * Can only be called by the proxy vault owner to avoid attacks where malicous actors can deposit 1 wei assets,
     * increasing gas costs upon credit issuance and withrawals.
     * Example inputs:
     * [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @param assetAddresses The contract addresses of the asset. For each asset to be deposited one address,
     * even if multiple assets of the same contract address are deposited.
     * @param assetIds The asset IDs that will be deposited for ERC721 & ERC1155.
     * When depositing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
     * @param assetAmounts The amounts of the assets to be deposited.
     * @param assetTypes The types of the assets to be deposited.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * Any other number = failed tx
     */
    function deposit(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external onlyOwner {
        uint256 assetAddressesLength = assetAddresses.length;

        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length
                && assetAddressesLength == assetTypes.length,
            "V_D: Length mismatch"
        );

        _deposit(assetAddresses, assetIds, assetAmounts, assetTypes, msg.sender);
    }

    /**
     * @notice Deposits assets into the proxy vault.
     * @dev Each index in each array corresponding to the same asset that will get deposited.
     * If multiple asset IDs of the same contract address
     * are deposited, the assetAddress must be repeated in assetAddresses.
     * The ERC20 gets deposited by transferFrom. ERC721 & ERC1155 using safeTransferFrom.
     * Example inputs:
     * [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @param assetAddresses The contract addresses of the asset. For each asset to be deposited one address,
     * even if multiple assets of the same contract address are deposited.
     * @param assetIds The asset IDs that will be deposited for ERC721 & ERC1155.
     * When depositing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
     * @param assetAmounts The amounts of the assets to be deposited.
     * @param assetTypes The types of the assets to be deposited.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * Any other number = failed tx
     * @param from The address to deposit from.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes,
        address from
    ) internal {
        //reverts in mainregistry if invalid input
        IRegistry(registry).batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetTypes[i] == 0) {
                _depositERC20(from, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _depositERC721(from, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _depositERC1155(from, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                require(false, "V_D: Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Processes withdrawals of assets by and to the owner of the proxy vault.
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
     * are to be withdrawn, the assetAddress must be repeated in assetAddresses.
     * The ERC20 get withdrawn by transfers. ERC721 & ERC1155 using safeTransferFrom.
     * Can only be called by the proxy vault owner.
     * Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
     * Will fail if "the value after withdrawal / open debt (including unrealised debt) > collateral threshold".
     * If no debt is taken yet on this proxy vault, users are free to withraw any asset at any time.
     * Example inputs:
     * [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @param assetAddresses The contract addresses of the asset. For each asset to be withdrawn one address,
     * even if multiple assets of the same contract address are withdrawn.
     * @param assetIds The asset IDs that will be withdrawn for ERC721 & ERC1155.
     * When withdrawing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
     * @param assetAmounts The amounts of the assets to be withdrawn.
     * @param assetTypes The types of the assets to be withdrawn.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * Any other number = failed tx
     */
    function withdraw(
        address[] calldata assetAddresses,
        uint256[] calldata assetIds,
        uint256[] calldata assetAmounts,
        uint256[] calldata assetTypes
    ) external onlyOwner {
        uint256 assetAddressesLength = assetAddresses.length;

        require(
            assetAddressesLength == assetIds.length && assetAddressesLength == assetAmounts.length
                && assetAddressesLength == assetTypes.length,
            "V_W: Length mismatch"
        );

        _withdraw(assetAddresses, assetIds, assetAmounts, assetTypes, msg.sender);

        uint256 usedMargin = getUsedMargin();
        if (usedMargin != 0) {
            require(getCollateralValue() > usedMargin, "V_W: coll. value too low!");
        }
    }

    /**
     * @notice Processes withdrawals of assets
     * @dev Each index in each array corresponding to the same asset that will get withdrawn.
     * If multiple asset IDs of the same contract address
     * are to be withdrawn, the assetAddress must be repeated in assetAddresses.
     * The ERC20 get withdrawn by transfers. ERC721 & ERC1155 using safeTransferFrom.
     * Will fail if balance on proxy vault is not sufficient for one of the withdrawals.
     * Example inputs:
     * [wETH, DAI, Bayc, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, Bayc, Bayc, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @param assetAddresses The contract addresses of the asset. For each asset to be withdrawn one address,
     * even if multiple assets of the same contract address are withdrawn.
     * @param assetIds The asset IDs that will be withdrawn for ERC721 & ERC1155.
     * When withdrawing an ERC20, this will be disregarded, HOWEVER a value (eg. 0) must be filled!
     * @param assetAmounts The amounts of the assets to be withdrawn.
     * @param assetTypes The types of the assets to be withdrawn.
     * 0 = ERC20
     * 1 = ERC721
     * 2 = ERC1155
     * Any other number = failed tx
     * @param to The address to withdraw to.
     */

    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        uint256[] memory assetTypes,
        address to
    ) internal {
        IRegistry(registry).batchProcessWithdrawal(assetAddresses, assetAmounts); //reverts in mainregistry if invalid input

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetTypes[i] == 0) {
                _withdrawERC20(to, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _withdrawERC721(to, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _withdrawERC1155(to, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                require(false, "V_W: Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Internal function used to deposit ERC20 tokens.
     * @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
     * After successful transfer, the function checks whether the same asset has been deposited.
     * This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
     * If the address has not yet been seen, the ERC20 token address is stored.
     * @param from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC20Address The asset address that should be transferred.
     * @param amount The amount of ERC20 tokens to be transferred.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) private {
        require(IERC20(ERC20Address).transferFrom(from, address(this), amount), "Transfer from failed");

        uint256 erc20StoredLength = erc20Stored.length;
        for (uint256 i; i < erc20StoredLength;) {
            if (erc20Stored[i] == ERC20Address) {
                return;
            }
            unchecked {
                ++i;
            }
        }

        erc20Stored.push(ERC20Address);
        //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
    }

    /**
     * @notice Internal function used to deposit ERC721 tokens.
     * @dev Used for all tokens types = 1. Note the transferFrom. No amounts are given since ERC721 are one-off's.
     * After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
     * This may cause duplicates in the ERC721 stored addresses array, but this is intended.
     * @param from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC721Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     */
    function _depositERC721(address from, address ERC721Address, uint256 id) private {
        IERC721(ERC721Address).transferFrom(from, address(this), id);

        erc721Stored.push(ERC721Address);
        //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
        erc721TokenIds.push(id);
    }

    /**
     * @notice Internal function used to deposit ERC1155 tokens.
     * @dev Used for all tokens types = 2. Note the safeTransferFrom.
     * After successful transfer, the function checks whether the combination of address & ID has already been stored.
     * If not, the function pushes the new address and ID to the stored arrays.
     * This may cause duplicates in the ERC1155 stored addresses array, but this is intended.
     * @param from The Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC1155Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     * @param amount The amount of ERC1155 tokens to be transferred.
     */
    function _depositERC1155(address from, address ERC1155Address, uint256 id, uint256 amount) private {
        IERC1155(ERC1155Address).safeTransferFrom(from, address(this), id, amount, "");

        bool addrSeen;

        uint256 erc1155StoredLength = erc1155Stored.length;
        for (uint256 i; i < erc1155StoredLength;) {
            if (erc1155Stored[i] == ERC1155Address) {
                if (erc1155TokenIds[i] == id) {
                    addrSeen = true;
                    break;
                }
            }
            unchecked {
                ++i;
            }
        }

        if (!addrSeen) {
            erc1155Stored.push(ERC1155Address); //TODO: see what the most gas efficient manner is to store/read/loop over this list to avoid duplicates
            erc1155TokenIds.push(id);
        }
    }

    /**
     * @notice Internal function used to withdraw ERC20 tokens.
     * @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
     * After successful transfer, the function checks whether the proxy vault has any leftover balance of said asset.
     * If not, it will pop() the ERC20 asset address from the stored addresses array.
     * Note: this shifts the order of erc20Stored!
     * This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
     * @param to Address the tokens should be sent to. This will in any case be the proxy vault owner
     * either being the original user or the liquidator!.
     * @param ERC20Address The asset address that should be transferred.
     * @param amount The amount of ERC20 tokens to be transferred.
     */
    function _withdrawERC20(address to, address ERC20Address, uint256 amount) private {
        require(IERC20(ERC20Address).transfer(to, amount), "Transfer from failed");

        if (IERC20(ERC20Address).balanceOf(address(this)) == 0) {
            uint256 erc20StoredLength = erc20Stored.length;

            if (erc20StoredLength == 1) {
                // there was only one ERC20 stored on the contract, safe to remove list
                erc20Stored.pop();
            } else {
                for (uint256 i; i < erc20StoredLength;) {
                    if (erc20Stored[i] == ERC20Address) {
                        erc20Stored[i] = erc20Stored[erc20StoredLength - 1];
                        erc20Stored.pop();
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
     * @notice Internal function used to withdraw ERC721 tokens.
     * @dev Used for all tokens types = 1. Note the safeTransferFrom. No amounts are given since ERC721 are one-off's.
     * After successful transfer, the function checks whether any other ERC721 is deposited in the proxy vault.
     * If not, it pops the stored addresses and stored IDs (pop() of two arrs is 180 gas cheaper than deleting).
     * If there are, it loops through the stored arrays and searches the ID that's withdrawn,
     * then replaces it with the last index, followed by a pop().
     * Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     * @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC721Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     */
    function _withdrawERC721(address to, address ERC721Address, uint256 id) private {
        uint256 tokenIdLength = erc721TokenIds.length;

        if (tokenIdLength == 1) {
            // there was only one ERC721 stored on the contract, safe to remove both lists
            erc721TokenIds.pop();
            erc721Stored.pop();
        } else {
            for (uint256 i; i < tokenIdLength;) {
                if (erc721TokenIds[i] == id && erc721Stored[i] == ERC721Address) {
                    erc721TokenIds[i] = erc721TokenIds[tokenIdLength - 1];
                    erc721TokenIds.pop();
                    erc721Stored[i] = erc721Stored[tokenIdLength - 1];
                    erc721Stored.pop();
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
     * @notice Internal function used to withdraw ERC1155 tokens.
     * @dev Used for all tokens types = 2. Note the safeTransferFrom.
     * After successful transfer, the function checks whether there is any balance left for that ERC1155.
     * If there is, it simply transfers the tokens.
     * If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
     * If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
     * and then replaces it with the last index, followed by a pop().
     * Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     * @param to Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC1155Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     * @param amount The amount of ERC1155 tokens to be transferred.
     */
    function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount) private {
        uint256 tokenIdLength = erc1155TokenIds.length;
        if (IERC1155(ERC1155Address).balanceOf(address(this), id) - amount == 0) {
            if (tokenIdLength == 1) {
                erc1155TokenIds.pop();
                erc1155Stored.pop();
            } else {
                for (uint256 i; i < tokenIdLength;) {
                    if (erc1155TokenIds[i] == id) {
                        if (erc1155Stored[i] == ERC1155Address) {
                            erc1155TokenIds[i] = erc1155TokenIds[tokenIdLength - 1];
                            erc1155TokenIds.pop();
                            erc1155Stored[i] = erc1155Stored[tokenIdLength - 1];
                            erc1155Stored.pop();
                            break;
                        }
                    }
                    unchecked {
                        ++i;
                    }
                }
            }
        }

        IERC1155(ERC1155Address).safeTransferFrom(address(this), to, id, amount, "");
    }

    /*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////*/

    function setAssetManager(address assetManager, bool value) external onlyOwner {
        isAssetManager[assetManager] = value;
    }

    /**
     * @notice Calls external action handlers to execute and interact with external logic.
     * @param actionHandler the address of the action handler to call
     * @param actionData a bytes object containing two actionAssetData structs, an address array and a bytes array
     * @dev Similar to flash loans, this function optimistically calls external logic and checks for the vault state at the very end.
     * @dev Asset managers can potentially steal assets (as long as the vault position remains healthy), only set trusted protocols as Asset manager.
     * Potential use-cases of the asset manager might be automate actions by keeper networks, 
     * or to chain interactions with trusted creditor together with vault actions (eg. borrow deposit and trade in one transaction). 
     */
    function vaultManagementAction(address actionHandler, bytes calldata actionData) public onlyAssetManager {
        require(IMainRegistry(registry).isActionAllowed(actionHandler), "VL_VMA: Action is not allowlisted");

        (ActionData memory outgoing,,,) = abi.decode(actionData, (ActionData, ActionData, address[], bytes[]));

        // withdraw to actionHandler
        _withdraw(outgoing.assets, outgoing.assetIds, outgoing.assetAmounts, outgoing.assetTypes, actionHandler);

        // execute Action
        ActionData memory incoming = IActionBase(actionHandler).executeAction(actionData);

        // deposit from actionHandler into vault
        _deposit(incoming.assets, incoming.assetIds, incoming.assetAmounts, incoming.assetTypes, actionHandler);

        uint256 collValue = getCollateralValue();
        uint256 usedMargin = getUsedMargin();
        require(collValue > usedMargin, "VMA: coll. value too low");
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Generates three arrays about the stored assets in the proxy vault
     * in the format needed for vault valuation functions.
     * @dev No balances are stored on the contract. Both for gas savings upon deposit and to allow for rebasing/... tokens.
     * Loops through the stored asset addresses and fills the arrays.
     * The vault valuation function fetches the asset type through the asset registries.
     * There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
     * @return assetAddresses An array of asset addresses.
     * @return assetIds An array of asset IDs. Will be '0' for ERC20's
     * @return assetAmounts An array of the amounts/balances of the asset on the proxy vault. wil be '1' for ERC721's
     */
    function generateAssetData()
        public
        view
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        uint256 totalLength;
        unchecked {
            totalLength = erc20Stored.length + erc721Stored.length + erc1155Stored.length;
        } //cannot practiaclly overflow. No max(uint256) contracts deployed
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength;) {
            cacheAddr = erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            //assetIds[i] = 0; //gas: no need to store 0, index will continue anyway
            assetAmounts[i] = IERC20(cacheAddr).balanceOf(address(this));
            unchecked {
                ++i;
            }
        }

        uint256 j;
        uint256 erc721StoredLength = erc721Stored.length;
        for (; j < erc721StoredLength;) {
            cacheAddr = erc721Stored[j];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc721TokenIds[j];
            assetAmounts[i] = 1;
            unchecked {
                ++i;
            }
            unchecked {
                ++j;
            }
        }

        uint256 k;
        uint256 erc1155StoredLength = erc1155Stored.length;
        for (; k < erc1155StoredLength;) {
            cacheAddr = erc1155Stored[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc1155TokenIds[k];
            assetAmounts[i] = IERC1155(cacheAddr).balanceOf(address(this), erc1155TokenIds[k]);
            unchecked {
                ++i;
            }
            unchecked {
                ++k;
            }
        }
    }

    function onERC721Received(address, address, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    fallback() external {
        revert();
    }
}
