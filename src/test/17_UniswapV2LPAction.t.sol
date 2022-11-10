/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../../lib/forge-std/src/Test.sol";
import "../mockups/UniswapV2Router02Mock.sol";
import "../mockups/UniswapV2FactoryMock.sol";
import "../mockups/UniswapV2PairMock.sol";
import "../Vault.sol";
import "../utils/Constants.sol";
import "../AssetManagement/actions/UniswapV2LPAction.sol";
import {ERC20Mock} from "../mockups/ERC20SolmateMock.sol";
import "../AssetRegistry/StandardERC20PricingModule.sol";
import "../AssetRegistry/UniswapV2PricingModule.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../OracleHub.sol";
import "../mockups/ArcadiaOracle.sol";

import "./fixtures/ArcadiaOracleFixture.f.sol";
import "../mockups/TrustedProtocolMock.sol";
import {FixedPointMathLib} from "../utils/FixedPointMathLib.sol";
import "../interfaces/IUniswapV2Pair.sol";

contract IUniswapV2LPActionExtension is UniswapV2LPAction {
    constructor(address _router, address _mainreg) UniswapV2LPAction(_router, _mainreg) {}

    function testPreCheck(bytes memory _actionSpecificData) public {
        _preCheck(_actionSpecificData);
    }

    function testExecute(
        address _vaultAddress,
        actionAssetsData memory _outgoing,
        actionAssetsData memory _incoming,
        bytes4 _selector
    ) public {
        _execute(_outgoing, _incoming, _selector);
    }
}

abstract contract UniswapV2LPActionTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock public dai;
    ERC20Mock public weth;

    UniswapV2PairMock public pairDaiWeth;
    UniswapV2Router02Mock public uniswapV2Router;
    UniswapV2FactoryMock public uniswapV2Factory;
    TrustedProtocolMock public trustedProtocol;

    ArcadiaOracle private oracleDaiToUsd;
    ArcadiaOracle private oracleWethToUsd;

    Vault vault;
    IUniswapV2LPActionExtension public action;

    StandardERC20PricingModule private standardERC20Registry;
    UniswapV2PricingModule public uniswapV2PricingModule;

    address public creatorAddress = address(1);
    address public tokenCreatorAddress = address(2);
    address public oracleOwner = address(3);
    address public samBankman = address(4);
    address public lpProvider = address(5);

    uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
    uint256 rateEthToUsd = 1300 * 10 ** Constants.oracleEthToUsdDecimals;

    address[] public oracleWethToUsdArr = new address[](1);
    address[] public oracleDaiToUsdArr = new address[](1);

    uint256[] emptyList = new uint256[](0);
    uint16[] emptyListUint16 = new uint16[](0);

    uint256 usdValue = 10 ** 6 * FixedPointMathLib.WAD;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //Before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        weth = new ERC20Mock("WETH Mock", "mWETH", uint8(Constants.ethDecimals));
        vm.stopPrank();

        vm.startPrank(samBankman);
        vault = new Vault();
        uniswapV2Factory = new UniswapV2FactoryMock();
        uniswapV2Factory.setFeeTo(address(1));
        pairDaiWeth = new UniswapV2PairMock();
        address pairDaiWethAddr = uniswapV2Factory.createPair(address(dai), address(weth));

        pairDaiWeth = UniswapV2PairMock(pairDaiWethAddr);
        trustedProtocol = new TrustedProtocolMock(dai, "tpDai", "trustedProtocolDai");
        uniswapV2Router = new UniswapV2Router02Mock(address(uniswapV2Factory));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleDaiToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD", rateDaiToUsd);
        oracleWethToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "WETH / USD", rateEthToUsd);

        vm.startPrank(creatorAddress);
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
        vm.stopPrank();

        oracleWethToUsdArr[0] = address(oracleWethToUsd);
        oracleDaiToUsdArr[0] = address(oracleDaiToUsd);

        vm.startPrank(creatorAddress);
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

        standardERC20Registry = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addPricingModule(address(standardERC20Registry));
        standardERC20Registry.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleDaiToUsdArr,
                assetUnit: uint64(10 ** Constants.daiDecimals),
                assetAddress: address(dai)
            }),
            emptyListUint16,
            emptyListUint16
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

        uniswapV2PricingModule = new UniswapV2PricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(uniswapV2Factory),
            address(standardERC20Registry)
        );
        mainRegistry.addPricingModule(address(uniswapV2PricingModule));

        // Action
        action = new IUniswapV2LPActionExtension(address(uniswapV2Router), address(mainRegistry));

        vm.stopPrank();

        // Cheat vault owner
        stdstore.target(address(vault)).sig(vault.owner.selector).checked_write(samBankman);

        // Cheat vault registry address
        stdstore.target(address(vault)).sig(vault.registryAddress.selector).checked_write(address(mainRegistry));

        // Cheat allowlisted actions in mainRegistry
        stdstore.target(address(mainRegistry)).sig(mainRegistry.isActionAllowlisted.selector).with_key(address(action))
            .checked_write(true);

        // Cheat Trusted Protocol
        stdstore.target(address(vault)).sig(vault.trustedProtocol.selector).checked_write(address(trustedProtocol));

        deal(address(dai), samBankman, 100000 * 10 ** Constants.daiDecimals, true);
        deal(address(weth), samBankman, 100000 * 10 ** Constants.ethDecimals, true);


        //stdstore.target(address(pairDaiWeth)).sig(pairDaiWeth.token0.selector).checked_write(130000000 * 10 ** Constants.daiDecimals);
        //stdstore.target(address(pairDaiWeth)).sig(pairDaiWeth.token1.selector).checked_write(100000 * 10 ** Constants.ethDecimals);


    }

    //Before Each
    function setUp() public virtual {}
}

/*//////////////////////////////////////////////////////////////
                        DEPLOYMENT
//////////////////////////////////////////////////////////////*/

contract DeploymentTest is UniswapV2LPActionTest {
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

contract executeActionTests is UniswapV2LPActionTest {
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    actionAssetsData _out;
    actionAssetsData _in;

    function setUp() public override {
        super.setUp();

        vm.startPrank(creatorAddress);
        uniswapV2PricingModule.setAssetInformation(address(pairDaiWeth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        //Deposit in vault
        address[] memory _assetAddresses = new address[](2);
        _assetAddresses[0] = address(dai);
        _assetAddresses[1] = address(weth);

        uint256[] memory _assetIds = new uint256[](2);
        _assetIds[0] = 0;
        _assetIds[1] = 0;
        uint256[] memory _assetAmounts = new uint256[](2);
        _assetAmounts[0] = 1300 * 10 ** Constants.daiDecimals;
        _assetAmounts[1] = 1 * 10 ** Constants.ethDecimals;
        uint256[] memory _assetTypes = new uint256[](2);
        _assetTypes[0] = 0;
        _assetTypes[1] = 0;

        vm.startPrank(samBankman);
        dai.approve(address(vault), type(uint256).max);
        weth.approve(address(vault), type(uint256).max);
        pairDaiWeth.approve(address(vault), type(uint256).max);
        vault.deposit(_assetAddresses, _assetIds, _assetAmounts, _assetTypes);
        vm.stopPrank();

        // Prepare outgoingData
        address[] memory outAssets = new address[](2);
        outAssets[0] = address(dai);
        outAssets[1] = address(weth);

        uint256[] memory outAssetsIds = new uint256[](2);
        outAssetsIds[0] = 0;
        outAssetsIds[1] = 0;

        uint256[] memory outAssetAmounts = new uint256[](2);
        outAssetAmounts[0] = 1300 * 10 ** Constants.daiDecimals;
        outAssetAmounts[1] = 1 * 10 ** Constants.ethDecimals;

        uint256[] memory outPreActionBalances = new uint256[](2);
        outPreActionBalances[0] = 0;
        outPreActionBalances[1] = 0;

        //  Prepare incomingData
        _out = actionAssetsData(outAssets, outAssetsIds, outAssetAmounts, outPreActionBalances);

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(pairDaiWeth);

        uint256[] memory _inAssetsIds = new uint256[](1);
        _inAssetsIds[0] = 1;

        uint256[] memory _inAssetAmounts = new uint256[](1);
        _inAssetAmounts[0] = 1 * 10 ** Constants.ethDecimals;

        uint256[] memory _inPreActionBalances = new uint256[](1);
        _inPreActionBalances[0] = 0;

        //  Prepare action data
        _in = actionAssetsData(_inAssets, _inAssetsIds, _inAssetAmounts, _inPreActionBalances);

  

    }

    /*///////////////////////////////
            ADD/REMOVE LP TESTS
    ///////////////////////////////*/

    function testSuccess_addDAIWETHLP() public {
        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        emit log_named_uint("dai balance", dai.balanceOf(address(vault)));
        emit log_named_uint("weth balance", weth.balanceOf(address(vault)));
        emit log_named_uint("pairDaiWeth balance", pairDaiWeth.balanceOf(address(vault)));
        emit log_named_address("pairDaiWethAddr", address(pairDaiWeth));

        vm.startPrank(address(action));
        dai.approve(address(uniswapV2Router), type(uint256).max);
        weth.approve(address(uniswapV2Router), type(uint256).max);
        pairDaiWeth.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        vm.prank(samBankman);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(weth.balanceOf(address(vault)), 0);
        assertEq(pairDaiWeth.balanceOf(address(vault)), 1 * 10 ** Constants.ethDecimals); // 1 LP token

        (uint112 reserve0, uint112 reserve1,) = pairDaiWeth.getReserves();
        // assertEq(reserve0, _out.assetAmounts[0]);
        // assertEq(reserve1, _out.assetAmounts[1]);
    }

    function testSuccess_removeODAIWETHLP() public {
        //Deposit in lp tokens in vault
        address[] memory _assetAddresses = new address[](1);
        _assetAddresses[0] = address(pairDaiWeth);
        uint256[] memory _assetIds = new uint256[](1);
        _assetIds[0] = 0;
        uint256[] memory _assetAmounts = new uint256[](1);
        _assetAmounts[0] = 1 * 10 ** Constants.ethDecimals;
        uint256[] memory _assetTypes = new uint256[](1);
        _assetTypes[0] = 0;

        vm.startPrank(samBankman);
        dai.approve(address(vault), type(uint256).max);
        weth.approve(address(vault), type(uint256).max);
        uniswapV2Router.addLiquidity(
            address(dai),
            address(weth),
            1300 * 10 ** Constants.daiDecimals,
            1 * 10 ** Constants.ethDecimals,
            1300 * 10 ** Constants.daiDecimals,
            1 * 10 ** Constants.ethDecimals,
            samBankman,
            block.timestamp + 1
        );
        vault.deposit(_assetAddresses, _assetIds, _assetAmounts, _assetTypes);
        vm.stopPrank();

        // Vault has 1 LP token
        // Intitiate action to remove 1 LP token and get underlying assets in vault
        vm.startPrank(address(action));
        dai.approve(address(uniswapV2Router), type(uint256).max);
        weth.approve(address(uniswapV2Router), type(uint256).max);
        pairDaiWeth.approve(address(uniswapV2Router), type(uint256).max);
        vm.stopPrank();

        bytes memory __actionSpecificData = abi.encode(_in, _out, bytes4(keccak256("remove")));
        vm.prank(samBankman);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 1300 * 10 ** Constants.daiDecimals);
        assertEq(weth.balanceOf(address(vault)), 1 * 10 ** Constants.ethDecimals);

        (uint112 reserve0, uint112 reserve1,) = pairDaiWeth.getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
    }

    function testSuccess_addDAIWETHLP_notEnoughDAI() public {
        _out.assetAmounts[0] = 1400 * 10 ** Constants.daiDecimals;

        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        vm.prank(samBankman);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }

    function testSuccess_addDAIWETHLP_notEnoughWETH() public {
        _out.assetAmounts[1] = 2 * 10 ** Constants.ethDecimals;

        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        vm.prank(samBankman);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }

    function testSuccess_removeDAIWETHLP_notEnoughLP() public {
        _in.assetAmounts[0] = 2 * 10 ** Constants.ethDecimals;

        bytes memory __actionSpecificData = abi.encode(_in, _out, bytes4(keccak256("remove")));

        vm.prank(samBankman);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }

    function testSuccess_removeDAIWETHLP_BaseTokens() public {
        address[] memory inAssets = new address[](1);
        inAssets[0] = address(dai);
        _in.assets = inAssets;
        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("remove")));

        vm.prank(samBankman);
        vm.expectRevert("UV2A_LP: Need atleast two base tokens");
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }

    function testSuccess_addDAIWETHLP_BaseTokens() public {
        address[] memory outAssets = new address[](1);
        outAssets[0] = address(dai);
        _out.assets = outAssets;
        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        vm.prank(samBankman);
        vm.expectRevert("UV2A_LP: Need atleast two base tokens");
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }

    function testSuccess_UnknownActionSelector() public {
        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("random")));

        vm.prank(samBankman);
        vm.expectRevert("UV2A_LP: invalid _selector");
        vault.vaultManagementAction(address(action), __actionSpecificData);
    }
}
