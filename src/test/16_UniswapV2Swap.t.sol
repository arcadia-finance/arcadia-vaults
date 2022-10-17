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
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract IUniswapV2SwapActionExtension is UniswapV2SwapAction {
    constructor(address _router, address _mainreg) UniswapV2SwapAction(_router, _mainreg) {}

    function testPreCheck(address _vaultAddress, bytes memory _actionSpecificData) public {
        _preCheck(_vaultAddress, _actionSpecificData);
    }

    function testExecute(
        address _vaultAddress,
        actionAssetsData memory _outgoing,
        actionAssetsData memory _incoming,
        address[] memory path
    ) public {
        _execute(_vaultAddress, _outgoing, _incoming, path);
    }

    function testPostCheck(
        address _vaultAddress,
        actionAssetsData memory outgoingAssets_,
        actionAssetsData memory incomingAssets_
    ) public {
        _postCheck(_vaultAddress, outgoingAssets_, incomingAssets_);
    }
}

abstract contract UniswapV2SwapActionTest is Test {
    using stdStorage for StdStorage;

    Vault vault;
    UniswapV2Router02Mock routerMock;
    // UniswapV2PairMock pairMock;
    // UniswapV2FactoryMock factoryMock;
    UniswapV2SwapAction action;

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

        // MainReg
        mainRegistry = new MainRegistry(MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            }));

        uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
        uint256 rateEthToUsd = 1300 * 10 ** Constants.oracleEthToUsdDecimals;

        oracleHub = new OracleHub();

        standardERC20Registry = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addPricingModule(address(standardERC20Registry));

        // Action
        action = new UniswapV2SwapAction(address(routerMock), address(mainRegistry));

        

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
        stdstore
            .target(address(vault))
            .sig(vault.owner.selector)
            .checked_write(vaultOwner);

        // Cheat vault registry address
        stdstore
            .target(address(vault))
            .sig(vault.registryAddress.selector)
            .checked_write(address(mainRegistry));

        // Cheat allowlisted actions in mainRegistry
        stdstore
            .target(address(mainRegistry))
            .sig(mainRegistry.isActionAllowlisted.selector)
            .with_key(address(action))
            .checked_write(true);
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
    actionAssetsData _out;
    actionAssetsData _in;
    function setUp() public override {
        super.setUp();

        //Give some initial DAI to vault to swap
        deal(address(dai), address(vault), 1300, true);

        // Prepare outgoingData
        address[] memory outAssets = new address[](1);
        outAssets[0] = address(dai);

        uint256[] memory outAssetsIds = new uint256[](1);
        outAssetsIds[0] = 0;

        uint256[] memory outAssetAmounts = new uint256[](1);
        outAssetAmounts[0] = 1300;

        uint256[] memory outPreActionBalances = new uint256[](1);
        outPreActionBalances[0] = 0;

        //  Prepare incomingData
         _out = actionAssetsData(outAssets, outAssetsIds, outAssetAmounts, outPreActionBalances);

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(weth);

        uint256[] memory _inAssetsIds = new uint256[](1);
        _inAssetsIds[0] = 1;

        uint256[] memory _inAssetAmounts = new uint256[](1);
        _inAssetAmounts[0] = 1;

        uint256[] memory _inPreActionBalances = new uint256[](1);
        _inPreActionBalances[0] = 0;

        //  Prepare action data
        _in = actionAssetsData(_inAssets, _inAssetsIds, _inAssetAmounts, _inPreActionBalances);

    }

    function testSuccess_SwapDAIWETH() public {
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(weth);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        bytes memory __actionData = abi.encode(address(vault), msg.sender, __actionSpecificData);

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 0);
        assertEq(weth.balanceOf(address(vault)), 1);
    }

    // TODO add reverts for not enough funds
    function testSuccess_SwapDAIWETHNotEnoughFunds() public {
        uint256[] memory _outAssetAmounts = new uint256[](1);
        _outAssetAmounts[0] = 1301;
        _out.assetAmounts = _outAssetAmounts;

        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(weth);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        bytes memory __actionData = abi.encode(address(vault), msg.sender, __actionSpecificData);

        vm.startPrank(vaultOwner);
        vm.expectRevert('NH{q != Arithmetic over/underflow');
        vault.vaultManagementAction(address(action), __actionSpecificData);
        vm.stopPrank();
    }

    function testSuccess_SwapIncomingNotWhitelisted() public {
        ERC20Mock shiba = new ERC20Mock("Shiba Mock", "mShiba", uint8(Constants.daiDecimals));

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(shiba);
        _in.assets = _inAssets;
    
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(shiba);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        bytes memory __actionData = abi.encode(address(vault), msg.sender, __actionSpecificData);

        vm.startPrank(vaultOwner);
        vm.expectRevert("UV2A_SWAP: Non-whitelisted incoming asset");
        vault.vaultManagementAction(address(action), __actionSpecificData);
        vm.stopPrank();

    }
    

    function testSuccess_ExecuteNotWhitelistedAction(address _action) public {
        vm.assume(_action != address(action));
        ERC20Mock shiba = new ERC20Mock("Shiba Mock", "mShiba", uint8(Constants.daiDecimals));

        address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(shiba);
        _in.assets = _inAssets;
    
        address[] memory path = new address[](2);
        path[0] = address(dai);
        path[1] = address(shiba);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        bytes memory __actionData = abi.encode(address(vault), msg.sender, __actionSpecificData);

        vm.startPrank(vaultOwner);
        vm.expectRevert("VL_VMA: Action is not allowlisted");
        vault.vaultManagementAction(address(_action), __actionSpecificData);
        vm.stopPrank();

    }

    // Test caller is not owner
    // Test call action directly and check 
    // Test with dynamic swap with right values
    // Not enough
    // Collat thresh hold liquidates vault
}
