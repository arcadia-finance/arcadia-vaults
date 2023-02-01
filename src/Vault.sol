/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.8.0 <0.9.0;

import {IERC20} from "./interfaces/IERC20.sol";
import {IERC721} from "./interfaces/IERC721.sol";
import {IERC1155} from "./interfaces/IERC1155.sol";
import {IMainRegistry} from "./interfaces/IMainRegistry.sol";
import {ITrustedCreditor} from "./interfaces/ITrustedCreditor.sol";
import {IActionBase, ActionData} from "./interfaces/IActionBase.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IVault} from "./interfaces/IVault.sol";
import {IOraclesHub} from "./PricingModules/interfaces/IOraclesHub.sol";
import {ActionData} from "./actions/utils/ActionData.sol";

/**
 * @title An Arcadia Vault used to manage all your assets and take margin.
 * @author Arcadia Finance
 * @notice Users can use this vault to deposit assets (ERC20, ERC721, ERC1155, ...).
 * The vault will denominate all the pooled assets into one baseCurrency (one unit of account, like usd or eth).
 * An increase of value of one asset will offset a decrease in value of another asset.
 * Users can use the single denominated value of all their assets to take margin (take credit line, financing for leverage...).
 * Ensure your total value denomination remains above the liquidation threshold, or risk being liquidated!
 * @dev Integrating this vault as means of margin/collateral management for your own protocol that requires collateral is encouraged.
 * Arcadia's vault functions will guarantee you a certain value of the vault.
 * For allowlists or liquidation strategies specific to your protocol, contact: dev at arcadia.finance
 */
contract Vault is IVault {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    uint256 public constant ASSET_LIMIT = 15;

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

    mapping(address => uint256) public erc20Balances;
    mapping(address => mapping(uint256 => uint256)) public erc1155Balances;

    uint256[] public erc721TokenIds;
    uint256[] public erc1155TokenIds;

    mapping(address => bool) public isAssetManager;

    struct AddressSlot {
        address value;
    }

    event Upgraded(address oldImplementation, address newImplementation, uint16 oldVersion, uint16 indexed newVersion);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
            msg.sender == owner || msg.sender == trustedCreditor || isAssetManager[msg.sender], "V: Only Asset Manager"
        );
        _;
    }

    constructor(address registry_, uint16 vaultVersion_) {
        // This will only be the owner of the vault logic implementation
        // and will not affect any subsequent proxy implementation using this vault logic
        owner = msg.sender;
        registry = registry_;
        vaultVersion = vaultVersion_;
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
     * @param registry_ The 'beacon' contract to which should be looked at for external logic.
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
    }

    /**
     * @notice Updates the vault version and stores a new address in the EIP1967 implementation slot.
     * @param newImplementation The contract with the new vault logic.
     * @param newRegistry The MainRegistry for this specific implementation (might be identical as the old registry)
     * @param data Arbitrary data, can contain instructions to execute on the new logic
     * @param newVersion The new version of the vault logic.
     */
    function upgradeVault(address newImplementation, address newRegistry, uint16 newVersion, bytes calldata data)
        external
        onlyFactory
    {
        if (isTrustedCreditorSet) {
            //If a trustedCreditor is set, new version should be compatible.
            //openMarginAccount() is a view function, cannot modify state.
            (bool success,,) = ITrustedCreditor(trustedCreditor).openMarginAccount(newVersion);
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
        //Data can be added by the factory for complex instructions.
        this.upgradeHook(oldImplementation, oldRegistry, oldVersion, data);

        emit Upgraded(oldImplementation, newImplementation, oldVersion, newVersion);
    }

    /**
     * @notice Returns an `AddressSlot` with member `value` located at `slot`.
     */
    function _getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }

    /**
     * @notice Finalizes the Upgrade to a new vault version on the new Logic Contract.
     * @param oldImplementation The contract with the new old logic.
     * @param oldRegistry The MainRegistry of the old version (might be identical as the new registry)
     * @param oldVersion The old version of the vault logic.
     * @param data Arbitrary data, can contain instructions to execute in thos function.
     * @dev If upgradeHook() is implemented, it MUST be verified that msg.sender == address(this)
     */
    function upgradeHook(address oldImplementation, address oldRegistry, uint16 oldVersion, bytes calldata data)
        external
    {}

    /* ///////////////////////////////////////////////////////////////
                        OWNERSHIP MANAGEMENT
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Transfers ownership of the contract to a new account.
     * @param newOwner The new owner of the Vault
     * @dev Can only be called by the current owner via the factory.
     * A transfer of ownership of the vault is triggered by a transfer
     * of ownership of the accompanying ERC721 Vault NFT issued by the factory.
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
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal {
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
     * @dev First checks if there is no locked value. If there is no value locked then a new baseCurrency is set.
     */
    function setBaseCurrency(address baseCurrency_) external onlyOwner {
        require(getUsedMargin() == 0, "V_SBC: Non-zero open position");
        _setBaseCurrency(baseCurrency_);
    }

    /**
     * @notice Internal function: sets baseCurrency.
     * @param baseCurrency_ the new baseCurrency for the vault.
     */
    function _setBaseCurrency(address baseCurrency_) internal {
        require(IMainRegistry(registry).isBaseCurrency(baseCurrency_), "V_SBC: baseCurrency not found");
        baseCurrency = baseCurrency_;
    }

    /* ///////////////////////////////////////////////////////////////
                    MARGIN ACCOUNT SETTINGS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Initiates a margin account on the vault for a trusted Creditor.
     * @param creditor The contract address of the trusted Creditor.
     * @dev Currently only one trusted Creditor can be set.
     * @dev Only open margin accounts for protocols you trust!
     * The Creditor should be trusted by the Vault Owner, but not by any of the Arcadia-vault smart contracts.
     * TrustedProtocol and Liquidator will never be called from an Arcadia Contract with a function that can modify state.
     * @dev The creditor has significant authorisation: use margin, trigger liquidation, and manage assets.
     */
    function openTrustedMarginAccount(address creditor) external onlyOwner {
        require(!isTrustedCreditorSet, "V_OTMA: ALREADY SET");

        //openMarginAccount() is a view function, cannot modify state.
        (bool success, address baseCurrency_, address liquidator_) =
            ITrustedCreditor(creditor).openMarginAccount(vaultVersion);
        require(success, "V_OTMA: Invalid Version");

        liquidator = liquidator_;
        trustedCreditor = creditor;
        if (baseCurrency != baseCurrency_) {
            _setBaseCurrency(baseCurrency_);
        }
        isTrustedCreditorSet = true;
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
    }

    /* ///////////////////////////////////////////////////////////////
                          MARGIN REQUIREMENTS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Called by trusted applications, checks if the Vault has sufficient free margin.
     * @param baseCurrency_ The Base-currency in which the Vault is denominated.
     * @param amount The amount the position is increased.
     * @return success Boolean indicating if there is sufficient free margin to increase the margin position.
     */
    function increaseMarginPosition(address baseCurrency_, uint256 amount) external view returns (bool success) {
        if (baseCurrency_ != baseCurrency) {
            return false;
        }

        // Check that the collateral value is bigger than the sum  of the already used margin and the increase
        // ToDo: For trusted creditors, already pass usedMargin with the call -> avoid additional hop back to trusted creditor to fetch already open debt
        success = getCollateralValue() >= getUsedMargin() + amount;
    }

    /**
     * @notice Checks if the Vault is healthy and still has free margin.
     * @param debtIncrease The amount with which the debt is increased.
     * @param totalOpenDebt The total open Debt against the Vault.
     * @return success Boolean indicating if there is sufficient margin to back a certain amount of Debt.
     * @dev Only one of the values can be non-zero, or we check on a certain increase of debt, or we check on a total amount of debt.
     * @dev If both values are zero, we check if the vault is currently healthy.
     */
    function isVaultHealthy(uint256 debtIncrease, uint256 totalOpenDebt) external view returns (bool success) {
        if (totalOpenDebt != 0) {
            //Check if vault is healthy for a given amount of openDebt.
            success = getCollateralValue() >= totalOpenDebt;
        } else {
            //Check if vault is still healthy after an increase of debt.
            success = getCollateralValue() >= getUsedMargin() + debtIncrease;
        }
    }

    /**
     * @notice Returns the total value of the vault in a specific baseCurrency
     * @dev Fetches all stored assets with their amounts on the proxy vault.
     * Using a specified baseCurrency, fetches the value of all assets on the proxy vault in said baseCurrency.
     * @param baseCurrency_ The basecurrency to return the value in.
     * @return vaultValue Total value stored on the vault, expressed in baseCurrency.
     */
    function getVaultValue(address baseCurrency_) external view returns (uint256 vaultValue) {
        (address[] memory assetAddresses, uint256[] memory assetIds, uint256[] memory assetAmounts) =
            generateAssetData();
        vaultValue = IMainRegistry(registry).getTotalValue(assetAddresses, assetIds, assetAmounts, baseCurrency_);
    }

    /**
     * @notice Calculates the total collateral value of the vault.
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
     * @notice Calculates the total liquidation value of the vault.
     * @return liquidationValue The liquidation value, returned in the decimals of the base currency.
     * @dev Returns the value denominated in the baseCurrency of the Vault.
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
        liquidationValue =
            IMainRegistry(registry).getLiquidationValue(assetAddresses, assetIds, assetAmounts, baseCurrency);
    }

    /**
     * @notice Returns the used margin of the proxy vault.
     * @return usedMargin The used amount of margin a user has taken
     * @dev The used margin is denominated in the baseCurrency of the proxy vault.
     * @dev Currently only one trusted application (Arcadia Lending) can open a margin account.
     * The open position is fetched at a contract of the application -> only allow trusted audited creditors!!!
     */
    function getUsedMargin() public view returns (uint256 usedMargin) {
        if (!isTrustedCreditorSet) return 0;

        //getOpenPosition() is a view function, cannot modify state.
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
     * @notice Function called by Liquidator to start liquidation of the Vault.
     * @param openDebt The open debt taken by `originalOwner` at moment of liquidation at trustedCreditor
     * @return originalOwner The original owner of this vault.
     * @return baseCurrency_ The baseCurrency in which the vault is denominated.
     * @return trustedCreditor_ The account or contract that is owed the debt.
     * @dev Requires an unhealthy vault (value / debt < liqFactor).
     * @dev Transfers ownership of the proxy vault to the liquidator!
     */
    function liquidateVault(uint256 openDebt)
        external
        returns (address originalOwner, address baseCurrency_, address trustedCreditor_)
    {
        require(msg.sender == liquidator, "V_LV: Only Liquidator");

        //If getLiquidationValue (total value discounted with liquidation factor) is smaller than openDebt,
        //the Vault is unhealthy and is succesfully liquidated.
        //Liquidations are triggered by the trustedCreditor (via Liquidator), the openDebt is
        //passed to avoid the need of another contract call back to trustedCreditor.
        require(getLiquidationValue() < openDebt, "V_LV: Vault is healthy");

        //Transfer ownership of the ERC721 in Factory of the Vault to the Liquidator.
        IFactory(IMainRegistry(registry).factory()).liquidate(msg.sender);

        //Transfer ownership of the Vault itself to the Liquidator
        originalOwner = owner;
        _transferOwnership(msg.sender);

        return (originalOwner, baseCurrency, trustedCreditor);
    }

    /*///////////////////////////////////////////////////////////////
                    ASSET MANAGEMENT LOGIC
    ///////////////////////////////////////////////////////////////*/

    /**
     * @notice Add or remove an Asset Manager.
     * @param assetManager the address of the Asset Manager
     * @param value A boolean giving permissions to or taking permissions from an Asset manager
     * @dev Only set trusted addresses as Asset manager, Asset managers can potentially steal assets (as long as the vault position remains healthy).
     * @dev No need to set the Owner as Asset manager, owner will automattically have all permissions of an asset manager.
     * @dev Potential use-cases of the asset manager might be to:
     * - Automate actions by keeper networks,
     * - Chain interactions with the Trusted Creditor together with vault actions (eg. borrow deposit and trade in one transaction).
     */
    function setAssetManager(address assetManager, bool value) external onlyOwner {
        isAssetManager[assetManager] = value;
    }

    /**
     * @notice Calls external action handler to execute and interact with external logic.
     * @param actionHandler The address of the action handler.
     * @param actionData A bytes object containing two actionAssetData structs, an address array and a bytes array.
     * @dev Similar to flash loans, this function optimistically calls external logic and checks for the vault state at the very end.
     * @dev vaultManagementAction can interact with and chain together any DeFi protocol to swap, stake, claim...
     * The only requirements are that the recipient tokens of the interactions are allowlisted, deposited back into the vault and
     * that the Vault is in a healthy state at the end of the transaction.
     */
    function vaultManagementAction(address actionHandler, bytes calldata actionData) external onlyAssetManager {
        require(IMainRegistry(registry).isActionAllowed(actionHandler), "V_VMA: Action not allowed");

        (ActionData memory outgoing,,,) = abi.decode(actionData, (ActionData, ActionData, address[], bytes[]));

        // withdraw to actionHandler
        _withdraw(outgoing.assets, outgoing.assetIds, outgoing.assetAmounts, outgoing.assetTypes, actionHandler);

        // execute Action
        ActionData memory incoming = IActionBase(actionHandler).executeAction(actionData);

        // deposit from actionHandler into vault
        _deposit(incoming.assets, incoming.assetIds, incoming.assetAmounts, incoming.assetTypes, actionHandler);

        uint256 usedMargin = getUsedMargin();
        if (usedMargin > 0) {
            uint256 collValue = getCollateralValue();
            require(collValue >= usedMargin, "V_VMA: coll. value too low");
        }
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

        require(erc20Stored.length + erc721Stored.length + erc1155Stored.length <= ASSET_LIMIT, "V_D: Too many assets");
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
        IMainRegistry(registry).batchProcessDeposit(assetAddresses, assetIds, assetAmounts);

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                //skip if amount is 0 to prevent storing addresses that have 0 balance
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
        IMainRegistry(registry).batchProcessWithdrawal(assetAddresses, assetIds, assetAmounts); //reverts in mainregistry if invalid input

        uint256 assetAddressesLength = assetAddresses.length;
        for (uint256 i; i < assetAddressesLength;) {
            if (assetAmounts[i] == 0) {
                //skip if amount is 0 to prevent transferring 0 balances
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
     * @notice Internal function used to deposit ERC20 tokens.
     * @dev Used for all tokens types = 0. Note the transferFrom, not the safeTransferFrom to allow legacy ERC20s.
     * If the address has not yet been deposited, the ERC20 token address is stored.
     * @param from Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC20Address The asset address that should be transferred.
     * @param amount The amount of ERC20 tokens to be transferred.
     */
    function _depositERC20(address from, address ERC20Address, uint256 amount) internal {
        require(IERC20(ERC20Address).transferFrom(from, address(this), amount), "V_D20: Transfer from failed");

        uint256 currentBalance = erc20Balances[ERC20Address];

        if (currentBalance == 0) {
            erc20Stored.push(ERC20Address);
        }

        unchecked {
            erc20Balances[ERC20Address] += amount;
        }
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
    function _depositERC721(address from, address ERC721Address, uint256 id) internal {
        IERC721(ERC721Address).transferFrom(from, address(this), id);

        erc721Stored.push(ERC721Address);
        erc721TokenIds.push(id);
    }

    /**
     * @notice Internal function used to deposit ERC1155 tokens.
     * @dev Used for all tokens types = 2. Note the safeTransferFrom.
     * After successful transfer, the function checks whether the combination of address & ID has already been stored.
     * If not, the function pushes the new address and ID to the stored arrays.
     * This may cause duplicates in the ERC1155 stored addresses array, this is intended.
     * @param from The Address the tokens should be taken from. This address must have pre-approved the proxy vault.
     * @param ERC1155Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     * @param amount The amount of ERC1155 tokens to be transferred.
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
     * @notice Internal function used to withdraw ERC20 tokens.
     * @dev Used for all tokens types = 0. Note the transfer, not the safeTransfer to allow legacy ERC20s.
     * The function checks whether the proxy vault has any leftover balance of said asset.
     * If not, it will pop() the ERC20 asset address from the stored addresses array.
     * Note: this shifts the order of erc20Stored!
     * This check is done using a loop: writing it in a mapping vs extra loops is in favor of extra loops in this case.
     * @param to Address the tokens should be sent to.
     * either being the original user or the liquidator!.
     * @param ERC20Address The asset address that should be transferred.
     * @param amount The amount of ERC20 tokens to be transferred.
     */
    function _withdrawERC20(address to, address ERC20Address, uint256 amount) internal {
        erc20Balances[ERC20Address] -= amount;

        if (erc20Balances[ERC20Address] == 0) {
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

        require(IERC20(ERC20Address).transfer(to, amount), "V_W20: Transfer failed");
    }

    /**
     * @notice Internal function used to withdraw ERC721 tokens.
     * @dev Used for all tokens types = 1. Note the safeTransferFrom. No amounts are given since ERC721 are one-off's.
     * The function checks whether any other ERC721 is deposited in the proxy vault.
     * If not, it pops the stored addresses and stored IDs (pop() of two arrs is 180 gas cheaper than deleting).
     * If there are, it loops through the stored arrays and searches the ID that's withdrawn,
     * then replaces it with the last index, followed by a pop().
     * Sensitive to ReEntrance attacks! SafeTransferFrom therefore done at the end of the function.
     * @param to Address the tokens should be transferred to.
     * @param ERC721Address The asset address that should be transferred.
     * @param id The ID of the token to be transferred.
     */
    function _withdrawERC721(address to, address ERC721Address, uint256 id) internal {
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

    /* ///////////////////////////////////////////////////////////////
                        HELPER FUNCTIONS
    /////////////////////////////////////////////////////////////// */

    /**
     * @notice Generates three arrays about the stored assets in the proxy vault
     * in the format needed for vault valuation functions.
     * @dev Balances are stored on the contract to prevent working around the deposit limits.
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
        for (; k < erc1155StoredLength;) {
            cacheAddr = erc1155Stored[k];
            assetAddresses[i] = cacheAddr;
            assetIds[i] = erc1155TokenIds[k];
            assetAmounts[i] = erc1155Balances[cacheAddr][erc1155TokenIds[k]];
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
