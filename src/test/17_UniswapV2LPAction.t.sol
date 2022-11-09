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

    // function testPostCheck(address _vaultAddress, actionAssetsData memory incomingAssets_) public {
    //     _postCheck(incomingAssets_);
    // }
}

abstract contract UniswapV2LPActionTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    UniswapV2Router02Mock public routerMock;
    UniswapV2FactoryMock public uniswapV2Factory;
    IUniswapV2LPActionExtension public action;
    TrustedProtocolMock public trustedProtocol;

    MainRegistry mainRegistry;
    StandardERC20PricingModule private standardERC20Registry;
    UniswapV2PricingModule public uniswapV2PricingModule;

    OracleHub private oracleHub;

    ArcadiaOracle private oracleDaiToUsd;
    ArcadiaOracle private oracleWethToUsd;

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(deployer);

    ERC20Mock public dai;
    ERC20Mock public weth;
    address public daiwethlp;

    address deployer = address(1);
    address vaultOwner = address(2);

    uint16[] emptyListUint16 = new uint16[](0);

    //Before
    constructor() {
        vm.startPrank(deployer);
        vault = new Vault();
      

        // Swappable ERC20
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        weth = new ERC20Mock("WETH Mock", "mWETH", uint8(Constants.ethDecimals));
        uniswapV2Factory = new UniswapV2FactoryMock();
        address daiwethlp = uniswapV2Factory.createPair(address(dai), address(weth));
        //daiwethpair = IUniswapV2Pair(daiwethlp);
        trustedProtocol = new TrustedProtocolMock(dai, "tpDai", "trustedProtocolDai");

        // Uniswap V2 Router
        routerMock = new UniswapV2Router02Mock(address(uniswapV2Factory));

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

        uniswapV2PricingModule = new UniswapV2PricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(uniswapV2Factory),
            address(standardERC20Registry)
        );
        mainRegistry.addPricingModule(address(uniswapV2PricingModule));
 
        // Action
        action = new IUniswapV2LPActionExtension(address(routerMock), address(mainRegistry));

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

        // standardERC20Registry.setAssetInformation(
        //     StandardERC20PricingModule.AssetInformation({
        //         oracleAddresses: oracleWethToUsdArr,
        //         assetUnit: uint64(10 ** Constants.ethDecimals),
        //         assetAddress: address(daiwethlp)
        //     }),
        //     emptyListUint16,
        //     emptyListUint16
        // );

        

        vm.stopPrank();

        // Cheat vault owner
        stdstore.target(address(vault)).sig(vault.owner.selector).checked_write(vaultOwner);

        // Cheat vault registry address
        stdstore.target(address(vault)).sig(vault.registryAddress.selector).checked_write(address(mainRegistry));

        // Cheat allowlisted actions in mainRegistry
        stdstore.target(address(mainRegistry)).sig(mainRegistry.isActionAllowlisted.selector).with_key(address(action))
            .checked_write(true);

        // Cheat Trusted Protocol
        stdstore.target(address(vault)).sig(vault.trustedProtocol.selector).checked_write(address(trustedProtocol));

        deal(address(dai), vaultOwner, 100000 * 10 ** Constants.daiDecimals, true);
        deal(address(weth), vaultOwner, 100000 * 10 ** Constants.ethDecimals, true);
        deal(address(daiwethlp), vaultOwner, 100000000 * 10 ** Constants.ethDecimals, true);
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

        //Give some initial DAI to vault to deposit

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

        vm.startPrank(vaultOwner);
        dai.approve(address(vault), type(uint256).max);
        weth.approve(address(vault), type(uint256).max);
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
        _inAssets[0] = address(daiwethlp);

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

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(weth.balanceOf(address(vault)), 1 * 10 ** Constants.ethDecimals);
        
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(daiwethlp).getReserves();
        assertEq(reserve0,  1300 * 10 ** Constants.daiDecimals);
        assertEq(reserve1, 1 * 10 ** Constants.ethDecimals);
    }

    function testSuccess_removeDAIWETHLP() public {

        bytes memory __actionSpecificData = abi.encode(_in, _out, bytes4(keccak256("remove")));

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 1300 * 10 ** Constants.daiDecimals);
        assertEq(weth.balanceOf(address(vault)), 1 * 10 ** Constants.ethDecimals);

        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(daiwethlp).getReserves();
        assertEq(reserve0, 0);
        assertEq(reserve1, 0);
    }

    function testSuccess_addDAIWETHLP_notEnoughDAI() public {

        _out.assetAmounts[0] = 1400 * 10 ** Constants.daiDecimals;

        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        vm.prank(vaultOwner);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
   

    }

    function testSuccess_addDAIWETHLP_notEnoughWETH() public {

        _out.assetAmounts[1] = 2 * 10 ** Constants.ethDecimals;

        bytes memory __actionSpecificData = abi.encode(_out, _in, bytes4(keccak256("add")));

        vm.prank(vaultOwner);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);

    }

    function testSuccess_removeDAIWETHLP_notEnoughLP() public {

        _in.assetAmounts[0] = 2 * 10 ** Constants.ethDecimals;

        bytes memory __actionSpecificData = abi.encode(_in, _out, bytes4(keccak256("remove")));

        vm.prank(vaultOwner);
        vm.expectRevert(stdError.arithmeticError);
        vault.vaultManagementAction(address(action), __actionSpecificData);
        
    }

    function testSuccess_UnknownActionSelector() public {

        bytes memory __actionSpecificData = abi.encode(_in, _out, bytes4(keccak256("random")));

        vm.prank(vaultOwner);
        vm.expectRevert("UV2A_LP: invalid _selector");
        vault.vaultManagementAction(address(action), __actionSpecificData);

    }


}
