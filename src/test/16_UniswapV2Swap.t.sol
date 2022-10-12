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
    
    MainRegistry mainreg;
    // StandardERC20PricingModule private standardERC20Registry;

    // OracleHub private oracleHub;

    // ArcadiaOracle private oracleDaiToUsd;
    // ArcadiaOracle private oracleEthToUsd;

    ERC20Mock dai;
    ERC20Mock weth;

    address deployer = address(1);
    address vaultOwner = address(2);

    

    //Before
    constructor() {
        vm.startPrank(deployer);
        vault = new Vault();
        routerMock = new UniswapV2Router02Mock();

        // Swappable ERC20
        dai = new ERC20Mock("DAI Mock", "mDAI", uint8(Constants.daiDecimals));
        weth = new ERC20Mock("WETH Mock", "mWETH", uint8(Constants.ethDecimals));

        // MainReg
        mainreg = new MainRegistry(MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            }));

        // uint256 rateDaiToUsd = 1 * 10 ** Constants.oracleDaiToUsdDecimals;
        // uint256 rateEthToUsd = 1300 * 10 ** Constants.oracleEthToUsdDecimals;

        // oracleHub = new OracleHub();

        // oracleDaiToUsd =
        //     arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleDaiToUsdDecimals), "DAI / USD", rateDaiToUsd);
        // oracleWEthToUsd =
        //     arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "WETH / USD", rateEthToUsd);


        // Action
        action = new UniswapV2SwapAction(address(routerMock), address(mainreg));
        

        vm.stopPrank();


        // Cheat vault owner
        uint256 slot = stdstore.target(address(vault)).sig(vault.owner.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 owner = bytes32(abi.encode(vaultOwner));
        vm.store(address(vault), loc, owner);

        // Cheat whitelisted action TODO add action whitelist

        // // Cheat whitelisted assets in mainreg
        // slot = stdstore.target(address(mainreg)).sig(vault.owner.selector).find();
        // loc = bytes32(slot);
        // bytes32 owner = bytes32(abi.encode(vaultOwner));
        // vm.store(address(vault), loc, owner);

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
    function setUp() public override {
        super.setUp();
        
        //Give some initial DAI to vault to swap
        deal(address(dai), address(vault), 10_000, true);
    }

    function testSucces_SwapDAIWETH() public {

       address[] memory outAssets = new address[](1);
        outAssets[0] = address(dai);

       uint256[] memory outAssetsIds = new uint256[](1);
        outAssetsIds[0] = 0;

       uint256[] memory outAssetAmounts = new uint256[](1);
        outAssetAmounts[0] = 1300;

       uint256[] memory outPreActionBalances = new uint256[](1);
       outPreActionBalances[0] = 0;

        //  Prepare action data
        actionAssetsData memory _out = actionAssetsData(
            outAssets,
            outAssetsIds,
            outAssetAmounts,
            outPreActionBalances
        );

       address[] memory _inAssets = new address[](1);
        _inAssets[0] = address(weth);

       uint256[] memory _inAssetsIds = new uint256[](1);
        _inAssetsIds[0] = 1;


       uint256[] memory _inAssetAmounts = new uint256[](1);
        _inAssetAmounts[0] = 1;

       uint256[] memory _inPreActionBalances = new uint256[](1);
        _inPreActionBalances[0] = 0;

        //  Prepare action data
        actionAssetsData memory _in = actionAssetsData(
            _inAssets,
            _inAssetsIds,
            _inAssetAmounts,
            _inPreActionBalances
        );

        address[] memory path = new address[](2);

        path[0] = address(dai);
        path[1] = address(weth);

        bytes memory __actionSpecificData = abi.encode(_out, _in, path);
        bytes memory __actionData = abi.encode(address(vault), msg.sender, __actionSpecificData);

        vm.prank(vaultOwner);
        vault.vaultManagementAction(address(action), __actionSpecificData);

        assertEq(dai.balanceOf(address(vault)), 8700);
        assertEq(weth.balanceOf(address(vault)), 1);



    }
}
