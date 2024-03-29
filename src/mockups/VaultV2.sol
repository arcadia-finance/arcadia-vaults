/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../utils/LogExpMath.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../interfaces/IERC4626.sol";
import "../interfaces/IMainRegistry.sol";
import "../interfaces/ITrustedCreditor.sol";
import "../interfaces/IActionBase.sol";
import { IFactory } from "../interfaces/IFactory.sol";
import { ActionData } from "../actions/utils/ActionData.sol";
import { ERC20, SafeTransferLib } from "../../lib/solmate/src/utils/SafeTransferLib.sol";

/**
 * @title An Arcadia Vault used to deposit a combination of all kinds of assets
 * @author Pragma Labs
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
contract VaultV2 {
    using SafeTransferLib for ERC20;

    /* //////////////////////////////////////////////////////////////
                                STORAGE
    ////////////////////////////////////////////////////////////// */

    // Storage slot with the address of the current implementation.
    // This is the hardcoded keccak-256 hash of: "eip1967.proxy.implementation" subtracted by 1.
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    // The maximum amount of different assets that can be used as collateral within an Arcadia Vault.
    uint256 public constant ASSET_LIMIT = 15;
    // Flag that indicates if a trusted creditor is set.
    bool public isTrustedCreditorSet;
    // The current Vault Version.
    uint16 public vaultVersion;
    // The contract address of the liquidator, address 0 if no trusted creditor is set.
    address public liquidator;
    // The estimated maximum cost to liquidate a Vault, will count as Used Margin when a trusted creditor is set.
    uint96 public fixedLiquidationCost;
    // The owner of the Vault.
    address public owner;
    // The contract address of the MainRegistry.
    address public registry;
    // The trusted creditor, address 0 if no trusted creditor is set.
    address public trustedCreditor;
    // The baseCurrency of the Vault in which all assets and liabilities are denominated.
    address public baseCurrency;

    // Array with all the contract address of ERC20 tokens in the vault.
    address[] public erc20Stored;
    // Array with all the contract address of ERC721 tokens in the vault.
    address[] public erc721Stored;
    // Array with all the contract address of ERC1155 tokens in the vault.
    address[] public erc1155Stored;
    // Array with all the corresponding id's for each ERC721 token in the vault.
    uint256[] public erc721TokenIds;
    // Array with all the corresponding id's for each ERC1155 token in the vault.
    uint256[] public erc1155TokenIds;

    // Map asset => balance.
    mapping(address => uint256) public erc20Balances;
    // Map asset => id => balance.
    mapping(address => mapping(uint256 => uint256)) public erc1155Balances;
    // Map owner => assetManager => flag.
    mapping(address => mapping(address => bool)) public isAssetManager;

    // Storage slot for the Vault logic, a struct to avoid storage conflict when dealing with upgradeable contracts.
    struct AddressSlot {
        address value;
    }

    /* //////////////////////////////////////////////////////////////
                                EVENTS
    ////////////////////////////////////////////////////////////// */

    event BaseCurrencySet(address baseCurrency);
    event TrustedMarginAccountChanged(address indexed protocol, address indexed liquidator);
    event AssetManagerSet(address indexed owner, address indexed assetManager, bool value);

    /* //////////////////////////////////////////////////////////////
                                MODIFIERS
    ////////////////////////////////////////////////////////////// */

    /**
     * @dev Throws if called by any account other than the factory address.
     */
    modifier onlyFactory() {
        require(msg.sender == IMainRegistry(registry).factory(), "V: Only Factory");
        _;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "V: Only Owner");
        _;
    }

    /**
     * @dev Throws if called by any account other than an asset manager or the owner.
     */
    modifier onlyAssetManager() {
        require(
            msg.sender == owner || msg.sender == trustedCreditor || isAssetManager[owner][msg.sender],
            "V: Only Asset Manager"
        );
        _;
    }

    /* //////////////////////////////////////////////////////////////
                                CONSTRUCTOR
    ////////////////////////////////////////////////////////////// */

    constructor() {
        // This will only be the owner of the vault logic implementation.
        // and will not affect any subsequent proxy implementation using this vault logic.
        owner = msg.sender;
    }

    /* ///////////////////////////////////////////////////////////////
                          VAULT MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates the variables of the vault
     * @dev A proxy will be used to interact with the vault logic.
     * Therefore everything is initialised through an init function.
     * This function will only be called (once) in the same transaction as the proxy vault creation through the factory.
     * @param owner_ The sender of the 'createVault' on the factory
     * @param registry_ The 'beacon' contract with the external logic.
     * @param vaultVersion_ The version of the vault logic.
     * @param baseCurrency_ The Base-currency in which the vault is denominated.
     */
    function initialize(address owner_, address registry_, uint16 vaultVersion_, address baseCurrency_) external {
        require(vaultVersion == 0 && owner == address(0), "V_I: Already initialized!");
        require(vaultVersion_ != 0, "V_I: Invalid vault version");
        owner = owner_;
        registry = registry_;
        vaultVersion = vaultVersion_;
        baseCurrency = baseCurrency_;

        emit BaseCurrencySet(baseCurrency_);
    }

    /**
     * @notice Updates the vault version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The contract with the new vault logic.
     * @param newRegistry The MainRegistry for this specific implementation (might be identical as the old registry)
     * @param data Arbitrary data, can contain instructions to execute when updating Vault to new logic
     * @param newVersion The new version of the vault logic.
     */
    function upgradeVault(address newImplementation, address newRegistry, uint16 newVersion, bytes calldata data)
        external
        onlyFactory
    {
        if (isTrustedCreditorSet) {
            //If a trustedCreditor is set, new version should be compatible.
            //openMarginAccount() is a view function, cannot modify state.
            (bool success,,,) = ITrustedCreditor(trustedCreditor).openMarginAccount(newVersion);
            require(success, "V_UV: Invalid vault version");
        }

        //Cache old parameters
        address oldImplementation = _getAddressSlot(_IMPLEMENTATION_SLOT).value;
        address oldRegistry = registry;
        uint16 oldVersion = vaultVersion;
        _getAddressSlot(_IMPLEMENTATION_SLOT).value = newImplementation;
        registry = newRegistry;
        vaultVersion = newVersion;

        //Hook on the new logic to finalize upgrade.
        //Used to eg. Remove exposure from old Registry and Add exposure to the new Registry.
        //Extra data can be added by the factory for complex instructions.
        this.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);

        //Event emitted by Factory.
    }

    /**
     * @notice Returns an `AddressSlot` with member `value` located at `slot`.
     * @param slot The slot where the address of the Logic contract is stored.
     * @return r The address stored in slot.
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
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Vault.
     * @dev Can only be called by the current owner via the factory.
     * A transfer of ownership of the vault is triggered by a transfer
     * of ownership of the accompanying ERC721 Vault NFT, issued by the factory.
     * Owner of Vault NFT = owner of vault
     */
    function transferOwnership(address newOwner) external onlyFactory {
        if (newOwner == address(0)) {
            revert("V_TO: INVALID_RECIPIENT");
        }
        _transferOwnership(newOwner);
    }

    /**
     * @notice Transfers ownership of the contract to a new account (`newOwner`).
     * @param newOwner The new owner of the Vault.
     */
    function _transferOwnership(address newOwner) internal {
        owner = newOwner;

        //Event emitted by Factory.
    }

    /* ///////////////////////////////////////////////////////////////
                        BASE CURRENCY LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Sets the baseCurrency of a vault.
     * @param baseCurrency_ the new baseCurrency for the vault.
     * @dev First checks if there is no trusted creditor set,
     * if there is none set, then a new baseCurrency is set.
     */
    function setBaseCurrency(address baseCurrency_) external onlyOwner {
        require(!isTrustedCreditorSet, "V_SBC: Trusted Creditor Set");
        _setBaseCurrency(baseCurrency_);
    }

    /**
     * @notice Internal function: sets baseCurrency.
     * @param baseCurrency_ the new baseCurrency for the vault.
     */
    function _setBaseCurrency(address baseCurrency_) internal {
        require(IMainRegistry(registry).isBaseCurrency(baseCurrency_), "V_SBC: baseCurrency not found");
        baseCurrency = baseCurrency_;

        emit BaseCurrencySet(baseCurrency_);
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Opens a margin account on the vault for a trusted Creditor.
     * @param creditor The contract address of the trusted Creditor.
     * @dev Currently only one trusted Creditor can be set
     * (we are working towards a single account for multiple creditors tho!).
     * @dev Only open margin accounts for protocols you trust!
     * The Creditor should be trusted by the Vault Owner, but not by any of the Arcadia-vault smart contracts.
     * TrustedProtocol and Liquidator will never be called from an Arcadia Contract with a function that can modify state.
     * @dev The creditor has significant authorisation: use margin, trigger liquidation, and manage assets.
     */
    function openTrustedMarginAccount(address creditor) external onlyOwner {
        require(!isTrustedCreditorSet, "V_OTMA: ALREADY SET");

        //openMarginAccount() is a view function, cannot modify state.
        (bool success, address baseCurrency_, address liquidator_, uint256 fixedLiquidationCost_) =
            ITrustedCreditor(creditor).openMarginAccount(vaultVersion);
        require(success, "V_OTMA: Invalid Version");

        liquidator = liquidator_;
        trustedCreditor = creditor;
        fixedLiquidationCost = uint96(fixedLiquidationCost_);
        if (baseCurrency != baseCurrency_) {
            _setBaseCurrency(baseCurrency_);
        }
        isTrustedCreditorSet = true;

        emit TrustedMarginAccountChanged(creditor, liquidator_);
    }

    /**
     * @notice Closes the margin account on the vault of the trusted application..
     * @dev Currently only one trusted creditor can be set.
     */
    function closeTrustedMarginAccount() external onlyOwner {
        require(isTrustedCreditorSet, "V_CTMA: NOT SET");
        //getOpenPosition() is a view function, cannot modify state.
        require(ITrustedCreditor(trustedCreditor).getOpenPosition(address(this)) == 0, "V_CTMA: NON-ZERO OPEN POSITION");

        isTrustedCreditorSet = false;
        trustedCreditor = address(0);
        liquidator = address(0);
        fixedLiquidationCost = 0;

        emit TrustedMarginAccountChanged(address(0), address(0));
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Checks if the Vault is healthy and still has free margin.
     * @param debtIncrease The amount with which the debt is increased.
     * @param totalOpenDebt The total open Debt against the Vault.
     * @return success Boolean indicating if there is sufficient margin to back a certain amount of Debt.
     * @return trustedCreditor_ The contract address of the trusted creditor.
     * @return vaultVersion_ The vault version.
     * @dev A Vault is healthy if the Collateral value is bigger than or equal to the Used Margin.
     * @dev Only one of the values can be non-zero, or we check on a certain increase of debt, or we check on a total amount of debt.
     * @dev If both values are zero, we check if the vault is currently healthy.
     */
    function isVaultHealthy(uint256 debtIncrease, uint256 totalOpenDebt)
        external
        view
        returns (bool success, address trustedCreditor_, uint256 vaultVersion_)
    {
        if (totalOpenDebt > 0) {
            //Check if vault is healthy for a given amount of openDebt.
            //The total Used margin equals the sum of the given amount of openDebt and the gas cost to liquidate.
            success = getCollateralValue() >= totalOpenDebt + fixedLiquidationCost;
        } else {
            //Check if vault is still healthy after an increase of debt.
            //The gas cost to liquidate is already taken into account in getUsedMargin().
            success = getCollateralValue() >= getUsedMargin() + debtIncrease;
        }

        return (success, trustedCreditor, vaultVersion);
    }

    /**
     * @notice Returns the total value (mark to market) of the vault in a specific baseCurrency
     * @param baseCurrency_ The baseCurrency to return the value in.
     * @return vaultValue Total value stored in the vault, denominated in baseCurrency.
     * @dev Fetches all stored assets with their amounts.
     * Using a specified baseCurrency, fetches the value of all assets in said baseCurrency.
     */
    function getVaultValue(address baseCurrency_) external view returns (uint256 vaultValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        vaultValue = IMainRegistry(registry).getTotalValue(assetAddresses, assetIds, assetAmounts, baseCurrency_);
    }

    /**
     * @notice Calculates the total collateral value (MTM discounted with a haircut) of the vault.
     * @return collateralValue The collateral value, returned in the decimals of the base currency.
     * @dev Returns the value denominated in the baseCurrency of the Vault.
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
        collateralValue =
            IMainRegistry(registry).getCollateralValue(assetAddresses, assetIds, assetAmounts, baseCurrency);
    }

    /**
     * @notice Calculates the total liquidation value (MTM discounted with a factor to account for slippage) of the vault.
     * @return liquidationValue The liquidation value, returned in the decimals of the base currency.
     * @dev Returns the value denominated in the baseCurrency of the Vault.
     * @dev The liquidation value of the vault is equal to the spot value of the underlying assets,
     * discounted by a haircut (the liquidation factor).
     * The liquidation value takes into account that not the full value of the assets can go towards
     * repaying the debt, A fraction of the value is lost due to:
     * slippage while liquidating the assets, fees for the auction initiator and a penalty to the protocol.
     */
    function getLiquidationValue() public view returns (uint256 liquidationValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        liquidationValue =
            IMainRegistry(registry).getLiquidationValue(assetAddresses, assetIds, assetAmounts, baseCurrency);
    }

    /**
     * @notice Returns the used margin of the Vault.
     * @return usedMargin The total amount of Margin that is currently in use to back liabilities.
     * @dev Used Margin is the value of the assets that is currently 'locked' to back:
     *  - All the liabilities issued against the Vault.
     *  - An additional fixed buffer to cover gas fees in case of a liquidation.
     * @dev The used margin is denominated in the baseCurrency.
     * @dev Currently only one trusted application (Arcadia Lending) can open a margin account.
     * The open liability is fetched at the contract of the application -> only allow trusted audited creditors!!!
     */
    function getUsedMargin() public view returns (uint256 usedMargin) {
        if (!isTrustedCreditorSet) return 0;

        //getOpenPosition() is a view function, cannot modify state.
        usedMargin = ITrustedCreditor(trustedCreditor).getOpenPosition(address(this)) + fixedLiquidationCost;
    }

    /**
     * @notice Calculates the remaining margin the owner of the Vault can use.
     * @return freeMargin The remaining amount of margin a user can take.
     * @dev Free Margin is the value of the assets that is still free to back additional liabilities.
     * @dev The free margin is denominated in the baseCurrency.
     */
    function getFreeMargin() public view returns (uint256 freeMargin) {
        uint256 collateralValue = getCollateralValue();
        uint256 usedMargin = getUsedMargin();

        //gas: explicit check is done to prevent underflow.
        unchecked {
            freeMargin = collateralValue > usedMargin ? collateralValue - usedMargin : 0;
        }
    }

    /* ///////////////////////////////////////////////////////////////
                          LIQUIDATION LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Function called by Liquidator to start liquidation of the Vault.
     * @param openDebt The open debt taken by `originalOwner` at moment of liquidation at trustedCreditor
     * @return originalOwner The original owner of this vault.
     * @return baseCurrency_ The baseCurrency in which the vault is denominated.
     * @return trustedCreditor_ The account or contract that is owed the debt.
     * @dev Requires an unhealthy vault.
     * @dev Transfers ownership of the Vault to the liquidator!
     */
    function liquidateVault(uint256 openDebt)
        external
        returns (address originalOwner, address baseCurrency_, address trustedCreditor_)
    {
        require(msg.sender == liquidator, "V_LV: Only Liquidator");

        //Cache trustedCreditor.
        trustedCreditor_ = trustedCreditor;

        //Close margin account.
        isTrustedCreditorSet = false;
        trustedCreditor = address(0);
        liquidator = address(0);

        //If getLiquidationValue (total value discounted with liquidation factor to account for slippage)
        //is smaller than the Used Margin: sum of the liabilities of the Vault (openDebt)
        //and the max gas cost to liquidate the vault (fixedLiquidationCost),
        //then the Vault is unhealthy and is successfully liquidated.
        //Liquidations are triggered by the trustedCreditor (via Liquidator), the openDebt is
        //passed as input to avoid the need of another contract call back to trustedCreditor.
        require(getLiquidationValue() < openDebt + fixedLiquidationCost, "V_LV: liqValue above usedMargin");

        //Set fixedLiquidationCost to 0 since margin account is closed.
        fixedLiquidationCost = 0;

        //Transfer ownership of the ERC721 in Factory of the Vault to the Liquidator.
        IFactory(IMainRegistry(registry).factory()).liquidate(msg.sender);

        //Transfer ownership of the Vault itself to the Liquidator.
        originalOwner = owner;
        _transferOwnership(msg.sender);

        emit TrustedMarginAccountChanged(address(0), address(0));

        return (originalOwner, baseCurrency, trustedCreditor_);
    }

    /*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or remove an Asset Manager.
     * @param assetManager the address of the Asset Manager
     * @param value A boolean giving permissions to or taking permissions from an Asset manager
     * @dev Only set trusted addresses as Asset manager, Asset managers can potentially steal assets (as long as the vault position remains healthy).
     * @dev No need to set the Owner as Asset manager, owner will automatically have all permissions of an asset manager.
     * @dev Potential use-cases of the asset manager might be to:
     * - Automate actions by keeper networks,
     * - Chain interactions with the Trusted Creditor together with vault actions (eg. borrow deposit and trade in one transaction).
     */
    function setAssetManager(address assetManager, bool value) external onlyOwner {
        isAssetManager[msg.sender][assetManager] = value;

        emit AssetManagerSet(msg.sender, assetManager, value);
    }

    /**
     * @notice Calls external action handler to execute and interact with external logic.
     * @param actionHandler The address of the action handler.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @return trustedCreditor_ The contract address of the trusted creditor.
     * @return vaultVersion_ The vault version.
     * @dev Similar to flash loans, this function optimistically calls external logic and checks for the vault state at the very end.
     * @dev vaultManagementAction can interact with and chain together any DeFi protocol to swap, stake, claim...
     * The only requirements are that the recipient tokens of the interactions are allowlisted, deposited back into the vault and
     * that the Vault is in a healthy state at the end of the transaction.
     */
    function vaultManagementAction(address actionHandler, bytes calldata actionData)
        external
        onlyAssetManager
        returns (address, uint256)
    {
        require(IMainRegistry(registry).isActionAllowed(actionHandler), "V_VMA: Action not allowed");

        (ActionData memory outgoing,,,) = abi.decode(actionData, (ActionData, ActionData, address[], bytes[]));

        // Withdraw assets to actionHandler.
        _withdraw(outgoing.assets, outgoing.assetIds, outgoing.assetAmounts, actionHandler);

        // Execute Action(s).
        ActionData memory incoming = IActionBase(actionHandler).executeAction(actionData);

        // Deposit assets from actionHandler into vault.
        _deposit(incoming.assets, incoming.assetIds, incoming.assetAmounts, actionHandler);

        //If usedMargin is equal to fixedLiquidationCost, the open liabilities are 0 and the Vault is always in a healthy state.
        uint256 usedMargin = getUsedMargin();
        if (usedMargin > fixedLiquidationCost) {
            //Vault must be healthy after actions are executed.
            require(getCollateralValue() >= usedMargin, "V_VMA: Vault Unhealthy");
        }

        return (trustedCreditor, vaultVersion);
    }

    /* ///////////////////////////////////////////////////////////////
                    ASSET DEPOSIT/WITHDRAWN LOGIC
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Deposits assets into the Vault.
     * @param assetAddresses Array of the contract addresses of the assets.
     * One address for each asset to be deposited, even if multiple assets of the same contract address are deposited.
     * @param assetIds Array of the IDs of the assets.
     * When depositing an ERC20 token, this will be disregarded, HOWEVER a value (eg. 0) must be set in the array!
     * @param assetAmounts Array with the amounts of the assets.
     * When depositing an ERC721 token, this will be disregarded, HOWEVER a value (eg. 1) must be set in the array!
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get deposited. If multiple asset IDs of the same contract address
     * are deposited, the assetAddress must be repeated in assetAddresses.
     * Example inputs:
     * [wETH, DAI, BAYC, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     */
    function deposit(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
    {
        //No need to check that all arrays have equal length, this check is already done in the MainRegistry.
        _deposit(assetAddresses, assetIds, assetAmounts, msg.sender);
    }

    /**
     * @notice Deposits assets into the Vault.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param from The address to withdraw the assets from.
     */
    function _deposit(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address from
    ) internal {
        //Reverts in mainRegistry if input is invalid.
        uint256[] memory assetTypes =
            IMainRegistry(registry).batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                //Skip if amount is 0 to prevent storing addresses that have 0 balance.
                unchecked {
                    ++i;
                }
                continue;
            }

            if (assetTypes[i] == 0) {
                _depositERC20(from, assetAddresses[i], assetAmounts[i]);
            } else if (assetTypes[i] == 1) {
                _depositERC721(from, assetAddresses[i], assetIds[i]);
            } else if (assetTypes[i] == 2) {
                _depositERC1155(from, assetAddresses[i], assetIds[i], assetAmounts[i]);
            } else {
                revert("V_D: Unknown asset type");
            }
            unchecked {
                ++i;
            }
        }

        require(erc20Stored.length + erc721Stored.length + erc1155Stored.length <= ASSET_LIMIT, "V_D: Too many assets");
    }

    /**
     * @notice Withdrawals assets from the Vault to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * One address for each asset to be withdrawn, even if multiple assets of the same contract address are withdrawn.
     * @param assetIds Array of the IDs of the assets.
     * When withdrawing an ERC20 token, this will be disregarded, HOWEVER a value (eg. 0) must be set in the array!
     * @param assetAmounts Array with the amounts of the assets.
     * When withdrawing an ERC721 token, this will be disregarded, HOWEVER a value (eg. 1) must be set in the array!
     * @dev All arrays should be of same length, each index in each array corresponding
     * to the same asset that will get withdrawn. If multiple asset IDs of the same contract address
     * are to be withdrawn, the assetAddress must be repeated in assetAddresses.
     * Example inputs:
     * [wETH, DAI, BAYC, Interleave], [0, 0, 15, 2], [10**18, 10**18, 1, 100], [0, 0, 1, 2]
     * [Interleave, Interleave, BAYC, BAYC, wETH], [3, 5, 16, 17, 0], [123, 456, 1, 1, 10**18], [2, 2, 1, 1, 0]
     * @dev Will fail if the value is in an unhealthy state after withdrawal (collateral value is smaller than the Used Margin).
     * If no debt is taken yet on this Vault, users are free to withdraw any asset at any time.
     */
    function withdraw(address[] calldata assetAddresses, uint256[] calldata assetIds, uint256[] calldata assetAmounts)
        external
        onlyOwner
    {
        //No need to check that all arrays have equal length, this check is already done in the MainRegistry.
        _withdraw(assetAddresses, assetIds, assetAmounts, msg.sender);

        uint256 usedMargin = getUsedMargin();
        //If usedMargin is equal to fixedLiquidationCost, the open liabilities are 0 and all assets can be withdrawn.
        if (usedMargin > fixedLiquidationCost) {
            //Vault must be healthy after assets are withdrawn.
            require(getCollateralValue() >= usedMargin, "V_W: Vault Unhealthy");
        }
    }

    /**
     * @notice Withdrawals assets from the Vault to the owner.
     * @param assetAddresses Array of the contract addresses of the assets.
     * @param assetIds Array of the IDs of the assets.
     * @param assetAmounts Array with the amounts of the assets.
     * @param to The address to withdraw to.
     */

    function _withdraw(
        address[] memory assetAddresses,
        uint256[] memory assetIds,
        uint256[] memory assetAmounts,
        address to
    ) internal {
        //Reverts in mainRegistry if input is invalid.
        uint256[] memory assetTypes =
            IMainRegistry(registry).batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts); //reverts in mainregistry if invalid input

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                //Skip if amount is 0 to prevent transferring 0 balances.
                unchecked {
                    ++i;
                }
                continue;
            }

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
     * @notice Internal function to deposit ERC20 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Vault.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 tokens.
     * @dev Used for all tokens type == 0.
     * @dev If the token has not yet been deposited, the ERC20 token address is stored.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) internal {
        ERC20(ERC20Address).safeTransferFrom(from, address(this), amount);

        uint256 currentBalance = erc20Balances[ERC20Address];

        if (currentBalance == 0) {
            erc20Stored.push(ERC20Address);
        }

        unchecked {
            erc20Balances[ERC20Address] += amount;
        }
    }

    /**
     * @notice Internal function to deposit ERC721 tokens.
     * @param from Address the tokens should be transferred from. This address must have approved the Vault.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all tokens type == 1.
     * @dev After successful transfer, the function pushes the ERC721 address to the stored token and stored ID array.
     * This may cause duplicates in the ERC721 stored addresses array, but this is intended.
     */
    function _depositERC721(address from, address ERC721Address, uint256 id) internal {
        IERC721(ERC721Address).safeTransferFrom(from, address(this), id);

        erc721Stored.push(ERC721Address);
        erc721TokenIds.push(id);
    }

    /**
     * @notice Internal function to deposit ERC1155 tokens.
     * @param from The Address the tokens should be transferred from. This address must have approved the Vault.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all tokens type == 2.
     * @dev After successful transfer, the function checks whether the combination of address & ID has already been stored.
     * If not, the function pushes the new address and ID to the stored arrays.
     * This may cause duplicates in the ERC1155 stored addresses array, this is intended.
     */
    function _depositERC1155(address from, address ERC1155Address, uint256 id, uint256 amount) internal {
        IERC1155(ERC1155Address).safeTransferFrom(from, address(this), id, amount, "");

        uint256 currentBalance = erc1155Balances[ERC1155Address][id];

        if (currentBalance == 0) {
            erc1155Stored.push(ERC1155Address);
            erc1155TokenIds.push(id);
        }

        unchecked {
            erc1155Balances[ERC1155Address][id] += amount;
        }
    }

    /**
     * @notice Internal function to withdraw ERC20 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC20Address The contract address of the asset.
     * @param amount The amount of ERC20 tokens.
     * @dev Used for all tokens type == 0.
     * @dev The function checks whether the Vault has any leftover balance of said asset.
     * If not, it will pop() the ERC20 asset address from the stored addresses array.
     * Note: this shifts the order of erc20Stored!
     * @dev This check is done using a loop:
     * gas usage of writing it in a mapping vs extra loops is in favor of extra loops in this case.
     */
    function _withdrawERC20(address to, address ERC20Address, uint256 amount) internal {
        erc20Balances[ERC20Address] -= amount;

        if (erc20Balances[ERC20Address] == 0) {
            uint256 erc20StoredLength = erc20Stored.length;

            if (erc20StoredLength == 1) {
                // There was only one ERC20 stored on the contract, safe to remove from array.
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

        ERC20(ERC20Address).safeTransfer(to, amount);
    }

    /**
     * @notice Internal function to withdraw ERC721 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC721Address The contract address of the asset.
     * @param id The ID of the ERC721 token.
     * @dev Used for all tokens type == 1.
     * @dev The function checks whether any other ERC721 is deposited in the Vault.
     * If not, it pops the stored addresses and stored IDs (pop() of two arrays is 180 gas cheaper than deleting).
     * If there are, it loops through the stored arrays and searches the ID that's withdrawn,
     * then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC721(address to, address ERC721Address, uint256 id) internal {
        uint256 tokenIdLength = erc721TokenIds.length;

        uint256 i;
        if (tokenIdLength == 1) {
            //There was only one ERC721 stored on the contract, safe to remove both lists.
            require(erc721TokenIds[0] == id && erc721Stored[0] == ERC721Address, "V_W721: Unknown asset");
            erc721TokenIds.pop();
            erc721Stored.pop();
        } else {
            for (i; i < tokenIdLength;) {
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
            //For loop should break, otherwise we never went into the if-branch, meaning the token being withdrawn
            //is unknown and not properly deposited.
            require(i < tokenIdLength, "V_W721: Unknown asset");
        }

        IERC721(ERC721Address).safeTransferFrom(address(this), to, id);
    }

    /**
     * @notice Internal function to withdraw ERC1155 tokens.
     * @param to Address the tokens should be sent to.
     * @param ERC1155Address The contract address of the asset.
     * @param id The ID of the ERC1155 tokens.
     * @param amount The amount of ERC1155 tokens.
     * @dev Used for all tokens types = 2.
     * @dev After successful transfer, the function checks whether there is any balance left for that ERC1155.
     * If there is, it simply transfers the tokens.
     * If not, it checks whether it can pop() (used for gas savings vs delete) the stored arrays.
     * If there are still other ERC1155's on the contract, it looks for the ID and token address to be withdrawn
     * and then replaces it with the last index, followed by a pop().
     * @dev Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     */
    function _withdrawERC1155(address to, address ERC1155Address, uint256 id, uint256 amount) internal {
        uint256 tokenIdLength = erc1155TokenIds.length;

        erc1155Balances[ERC1155Address][id] -= amount;

        if (erc1155Balances[ERC1155Address][id] == 0) {
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

    /**
     * @notice Skims non-deposited assets from the Vault.
     * @param token The contract address of the asset.
     * @param id The ID of the asset.
     * @param type_ The asset type of the asset.
     * @dev Function can retrieve assets that were transferred to the Vault but not deposited.
     * or can be used to claim yield for rebasing tokens.
     */
    function skim(address token, uint256 id, uint256 type_) public {
        require(msg.sender == owner, "V_S: Only owner can skim");

        if (token == address(0)) {
            payable(owner).transfer(address(this).balance);
            return;
        }

        if (type_ == 0) {
            uint256 balance = ERC20(token).balanceOf(address(this));
            uint256 balanceStored = erc20Balances[token];
            if (balance > balanceStored) {
                ERC20(token).safeTransfer(owner, balance - balanceStored);
            }
        } else if (type_ == 1) {
            bool isStored;
            uint256 erc721StoredLength = erc721Stored.length;
            for (uint256 i; i < erc721StoredLength;) {
                if (erc721Stored[i] == token && erc721TokenIds[i] == id) {
                    isStored = true;
                    break;
                }
                unchecked {
                    ++i;
                }
            }

            if (!isStored) {
                IERC721(token).safeTransferFrom(address(this), owner, id);
            }
        } else if (type_ == 2) {
            uint256 balance = IERC1155(token).balanceOf(address(this), id);
            uint256 balanceStored = erc1155Balances[token][id];

            if (balance > balanceStored) {
                IERC1155(token).safeTransferFrom(address(this), owner, id, balance - balanceStored, "");
            }
        }
    }

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Generates three arrays of all the stored assets in the Vault.
     * @return assetAddresses Array of the contract addresses of the assets.
     * @return assetIds Array of the IDs of the assets.
     * @return assetAmounts Array with the amounts of the assets.
     * @dev Balances are stored on the contract to prevent working around the deposit limits.
     * @dev Loops through the stored asset addresses and fills the arrays.
     * @dev There is no importance of the order in the arrays, but all indexes of the arrays correspond to the same asset.
     */
    function generateAssetData()
        public
        view
        returns (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts)
    {
        uint256 totalLength;
        unchecked {
            totalLength = erc20Stored.length + erc721Stored.length + erc1155Stored.length;
        } //Cannot realistically overflow. No max(uint256) contracts deployed.
        assetAddresses = new address[](totalLength);
        assetIds = new uint256[](totalLength);
        assetAmounts = new uint256[](totalLength);

        uint256 i;
        uint256 erc20StoredLength = erc20Stored.length;
        address cacheAddr;
        for (; i < erc20StoredLength;) {
            cacheAddr = erc20Stored[i];
            assetAddresses[i] = cacheAddr;
            //assetIds[i] = 0; //gas: no need to store 0, index will continue anyway.
            assetAmounts[i] = erc20Balances[cacheAddr];
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
        uint256 cacheId;
        for (; k < erc1155StoredLength;) {
            cacheAddr = erc1155Stored[k];
            cacheId = erc1155TokenIds[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = cacheId;
            assetAmounts[i] = erc1155Balances[cacheAddr][cacheId];
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

    function returnFive() public pure returns (uint256) {
        return 5;
    }

    /**
     * @notice Finalizes the Upgrade to a new vault version on the new Logic Contract.
     * param oldImplementation The contract with the new old logic.
     * @param oldRegistry The MainRegistry of the old version (might be identical as the new registry)
     * param oldVersion The old version of the vault logic.
     * param data Arbitrary data, can contain instructions to execute in this function.
     * @dev If upgradeHook() is implemented, it MUST be verify that msg.sender == address(this).
     */
    function upgradeHook(address, address oldRegistry, uint16, bytes calldata) external {
        require(msg.sender == address(this), "Not the right address");
        IMainRegistry(oldRegistry).batchProcessWithdrawal(new address[](0), new uint256[](0), new uint256[](0));
        IMainRegistry(registry).batchProcessDeposit(new address[](0), new uint256[](0), new uint256[](0));

        check = returnFive();
    }

    uint256 public check;
}
