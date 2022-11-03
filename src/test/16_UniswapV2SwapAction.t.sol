/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import "../AssetManagement/actions/UniswapV2SwapAction.sol";
import "../mockups/UniswapV2Router02Mock.sol";
import "../Vault.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../utils/Constants.sol";
import {ERC20Mock} from "../mockups/ERC20SolmateMock.sol";
import "../AssetRegistry/StandardERC20PricingModule.sol";
import "../OracleHub.sol";
import "../mockups/ArcadiaOracle.sol";
import "../mockups/TrustedProtocolMock.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";

contract IUniswapV2SwapActionExtension is UniswapV2SwapAction {
    constructor(address _router, address _mainreg) UniswapV2SwapAction(_router, _mainreg) {}

    function testPreCheck(bytes memory _actionSpecificData) public view {
        _preCheck(_actionSpecificData);
    }

    function testExecute(
        actionAssetsData memory _outgoing,
        actionAssetsData memory _incoming,
        address[] memory path
    ) public {
        _execute(_outgoing, _incoming, path);
    }
}

abstract contract UniswapV2SwapActionTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    UniswapV2Router02Mock routerMock;
    IUniswapV2SwapActionExtension action;
    TrustedProtocolMock public trustedProtocol;

    MainRegistry mainRegistry;
    StandardERC20PricingModule private standardERC20Registry;

    OracleHub private oracleHub;

    ArcadiaOracle private oracleDaiToUsd;
    ArcadiaOracle private oracleWethToUsd;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(deployer);

    ERC20Mock dai;
    ERC20Mock weth;

    address deployer = address(1);
    address vaultOwner = address(2);

    uint16[] emptyListUint16 = new uint16[](0);

    //Before
    constructor() {
        vm.startPrank(deployer);
        vault = new Vault();
        routerMock = new UniswapV2Router02Mock();

        // Swappable ERC20
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        weth = new ERC20Mock("WETH Mock", "mWETH", uint8(Constants.ethDecimals));

        trustedProtocol = new TrustedProtocolMock(dai, "tpDai", "trustedProtocolDai");

        // MainReg
        mainRegistry = new MainRegistry(MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            }));

        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );

        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(weth),
                baseCurrencyToUsdOracle: address(oracleWethToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            emptyListUint16,
            emptyListUint16
        );

        uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
        uint256 rateEthToUsd = 1300 * 10 ** Constants.oracleEthToUsdDecimals;

        oracleHub = new OracleHub();

        standardERC20Registry = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addPricingModule(address(standardERC20Registry));

        // Action
        action = new IUniswapV2SwapActionExtension(address(routerMock), address(mainRegistry));

        vm.stopPrank();

        oracleDaiToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD", rateDaiToUsd);
        oracleWethToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "WETH / USD", rateEthToUsd);

        address[] memory oracleWethToUsdArr = new address[](1);
        address[] memory oracleDaiToUsdArr = new address[](1);

        oracleWethToUsdArr[0] = address(oracleWethToUsd);
        oracleDaiToUsdArr[0] = address(oracleDaiToUsd);

        vm.startPrank(deployer);

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "WETH",
                baseAsset: "USD",
                oracleAddress: address(oracleWethToUsd),
                quoteAssetAddress: address(weth),
                baseAssetIsBaseCurrency: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleDaiToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "DAI",
                baseAsset: "USD",
                oracleAddress: address(oracleDaiToUsd),
                quoteAssetAddress: address(dai),
                baseAssetIsBaseCurrency: true
            })
        );

        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleWethToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(weth)
            }),
            emptyListUint16,
            emptyListUint16
        );

        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleDaiToUsdArr,
                assetUnit: uint64(10 ** Constants.daiDecimals),
                assetAddress: address(dai)
            }),
            emptyListUint16,
            emptyListUint16
        );

        vm.stopPrank();

        // Cheat vault owner
        stdstore.target(address(vault)).sig(vault.owner.selector).checked_write(vaultOwner);

        // Cheat vault registry address
        stdstore.target(address(vault)).sig(vault.registryAddress.selector).checked_write(address(mainRegistry));

        // Cheat allowlisted actions in mainRegistry
        stdstore.target(address(mainRegistry)).sig(mainRegistry.isActionAllowlisted.selector).with_key(address(action))
            .checked_write(true);

        stdstore.target(address(vault)).sig(vault.trustedProtocol.selector).checked_write(address(trustedProtocol));

        deal(address(dai), vaultOwner, 100000 * 10 ** Constants.daiDecimals, true);
    }

    //Before Each
    function setUp() public virtual {}
}

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
//////////////////////////////////////////////////////////////*/

contract DeploymentTest is UniswapV2SwapActionTest {
    using stdStorage for StdStorage;

    function setUp() public override {
        super.setUp();
    }

    function testSuccess_deployment() public {
        // Assert that all part of a swapAction are deployed and ready to be tested
    }
}

/*//////////////////////////////////////////////////////////////
                        ACTION SPECIFIC LOGIC
//////////////////////////////////////////////////////////////*/

contract executeActionTests is UniswapV2SwapActionTest {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    actionAssetsData _out;
    actionAssetsData _in;
    address[] path;

    function setUp() public override {
        super.setUp();

        //Give some initial DAI to vault to deposit

        //Deposit in vault
        address[] memory _assetAddresses = new address[](1);
        _assetAddresses[0] = address(dai);
        uint256[] memory _assetIds = new uint256[](1);
        _assetIds[0] = 1;
        uint256[] memory _assetAmounts = new uint256[](1);
        _assetAmounts[0] = 1300 * 10 ** Constants.daiDecimals;
        uint256[] memory _assetTypes = new uint256[](1);
        _assetTypes[0] = 0;

        vm.startPrank(vaultOwner);
        dai.approve(address(vault), type(uint256).max);
        vault.deposit(_assetAddresses, _assetIds, _assetAmounts, _assetTypes);
        vm.stopPrank();

        // Prepare outgoingData
        address[] memory outAssets = new address[](1);
        outAssets[0] = address(dai);

        uint256[] memory outAssetsIds = new uint256[](1);
        outAssetsIds[0] = 0;

        uint256[] memory outAssetAmounts = new uint256[](1);
        outAssetAmounts[0] = 1300 * 10 ** Constants.daiDecimals;

        uint256[] memory outPreActionBalances = new uint256[](1);
        outPreActionBalances[0] = 0;

        //  Prepare incomingData
        _out = actionAssetsData(outAssets, outAssetsIds, outAssetAmounts, outPreActionBalances);

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(weth);

        uint256[] memory _inAssetsIds = new uint256[](1);
        _inAssetsIds[0] = 1;

        uint256[] memory _inAssetAmounts = new uint256[](1);
        _inAssetAmounts[0] = 1 * 10 ** Constants.ethDecimals;

        uint256[] memory _inPreActionBalances = new uint256[](1);
        _inPreActionBalances[0] = 0;

        path = new address[](2);
        path[0] = address(dai);
        path[1] = address(weth);

        //  Prepare action data
        _in = actionAssetsData(_inAssets, _inAssetsIds, _inAssetAmounts, _inPreActionBalances);
    }

    /*///////////////////////////////
            COMPLETE SWAP TESTS
    ///////////////////////////////*/

    function testSuccess_SwapDAIWETH() public {
        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);
        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(weth.balanceOf(address(vault)), 1 * 10 ** Constants.ethDecimals);
    }

    function testSuccess_SwapDAIWETHNotEnoughFunds() public {
        uint256[] memory _outAssetAmounts = new uint256[](1);
        _outAssetAmounts[0] = 1301 * 10 ** Constants.daiDecimals; //TODO: make this generic
        _out.assetAmounts = _outAssetAmounts;

        path = new address[](2);
        path[0] = address(dai);
        path[1] = address(weth);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.startPrank(vaultOwner);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
        vm.stopPrank();
    }

    function testSuccess_SwapTwoGenericAssetAmounts(uint256 _outAssetAmount) public {
        vm.assume(_outAssetAmount < 1000000000000000 * 10 ** 18);
        vm.assume((_outAssetAmount * 10 ** Constants.daiDecimals) < dai.balanceOf(address(vault)));
        uint256 _inAssetAmount = _outAssetAmount.divWadDown(1300);

        uint256[] memory _outAssets = new uint256[](1);
        _outAssets[0] = _outAssetAmount * 10 ** Constants.daiDecimals;
        _out.assetAmounts = _outAssets;

        uint256[] memory _inAssets = new uint256[](1);
        _inAssets[0] = _inAssetAmount * 10 ** Constants.ethDecimals;
        _in.assetAmounts = _inAssets;

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        //assertEq(dai.balanceOf(address(vault)), _out.preActionBalances[0] - (_outAssetAmount * 10 ** Constants.daiDecimals));
        assertEq(weth.balanceOf(address(vault)), _inAssetAmount * 10 ** Constants.ethDecimals);
    }

    /*///////////////////////////////
            VAULT TESTS
    ///////////////////////////////*/

    function testSuccess_ExecuteNotAllowlistedAction(address _action) public {
        vm.assume(_action != address(action));

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.startPrank(vaultOwner);
        vm.expectRevert("VL_VMA: Action is not allowlisted");
        vault.vaultManagementAction(address(_action), __actionSpecificData);
        vm.stopPrank();
    }

    /*///////////////////////////////
            PRECHECK TESTS
    ///////////////////////////////*/

    function testSuccess_PathLengthMustBeTwoOrMore() public {
        path = new address[](1);
        path[0] = address(dai);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.startPrank(vaultOwner);
        vm.expectRevert("UV2A_SWAP: _path must be >= 2");
        action.testPreCheck(__actionSpecificData);
        vm.stopPrank();
    }

    function testSuccess_SwapIncomingAssetNotAllowlisted() public {
        ERC20Mock shiba = new ERC20Mock("Shiba Mock", "mShiba", uint8(Constants.daiDecimals));

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(shiba);
        _in.assets = _inAssets;

        path = new address[](2);
        path[0] = address(dai);
        path[1] = address(shiba);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);

        vm.startPrank(vaultOwner);
        vm.expectRevert("UV2A_SWAP: Non-allowlisted incoming asset");
        action.testPreCheck(__actionSpecificData);
        vm.stopPrank();
    }

    /*///////////////////////////////
            EXECUTE TESTS
    ///////////////////////////////*/

    function testSuccess_CollValueBelowUsedMargin() public {
        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        
        stdstore.target(address(trustedProtocol)).sig(trustedProtocol.balanceOf.selector).with_key(address(vault))
            .checked_write(10000 * 10 ** Constants.daiDecimals);

        vm.startPrank(vaultOwner);
        vm.expectRevert("UV2_SWAP: coll. value postAction too low");
        vault.vaultManagementAction(address(action), __actionSpecificData);
        vm.stopPrank();
    }
}
