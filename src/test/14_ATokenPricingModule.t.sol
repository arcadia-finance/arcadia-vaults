/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../mockups/ERC20SolmateMock.sol";
import "../mockups/ATokenMock.sol";
import "../OracleHub.sol";
import "../utils/Constants.sol";
import "../AssetRegistry/ATokenPricingModule.sol";
import "../AssetRegistry/StandardERC20PricingModule.sol";
import "../AssetRegistry/MainRegistry.sol";
import "../mockups/ArcadiaOracle.sol";
import "./fixtures/ArcadiaOracleFixture.f.sol";

contract aTokenPricingModuleTest is Test {
    using stdStorage for StdStorage;

    OracleHub private oracleHub;
    MainRegistry private mainRegistry;

    ERC20Mock private eth;
    ATokenMock private aEth;

    ArcadiaOracle private oracleEthToUsd;

    StandardERC20PricingModule private standardERC20PricingModule;
    ATokenPricingModule private aTokenPricingModule;

    address private creatorAddress = address(1);
    address private tokenCreatorAddress = address(2);
    address private oracleOwner = address(3);

    uint256 rateEthToUsd = 1850 * 10 ** Constants.oracleEthToUsdDecimals;

    address[] public oracleEthToUsdArr = new address[](1);

    uint256[] emptyList = new uint256[](0);
    uint16[] emptyListUint16 = new uint16[](0);

    // FIXTURES
    ArcadiaOracleFixture arcadiaOracleFixture = new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20Mock("ETH Mock", "mETH", uint8(Constants.ethDecimals));
        aEth = new ATokenMock   (address(eth), "aETH Mock", "maETH");
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        oracleHub = new OracleHub();
        vm.stopPrank();

        oracleEthToUsd =
            arcadiaOracleFixture.initMockedOracle(uint8(Constants.oracleEthToUsdDecimals), "ETH / USD", rateEthToUsd);

        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetBaseCurrency: uint8(Constants.UsdBaseCurrency),
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsBaseCurrency: true
            })
        );
        vm.stopPrank();

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new MainRegistry(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                baseCurrencyToUsdOracle: 0x0000000000000000000000000000000000000000,
                baseCurrencyLabel: "USD",
                baseCurrencyUnitCorrection: uint64(10**(18 - Constants.usdDecimals))
            })
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            })
        );

        standardERC20PricingModule = new StandardERC20PricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        aTokenPricingModule = new ATokenPricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(aTokenPricingModule));

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyListUint16,
            emptyListUint16
        );
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_NonOwnerAddsAsset(address unprivilegedAddress) public {
        vm.assume(unprivilegedAddress != creatorAddress);
        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("Ownable: caller is not the owner");
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();
    }

    function testRevert_setAssetInformation_OwnerAddsAssetWithWrongNumberOfRiskVariables() public {
        vm.startPrank(creatorAddress);
        uint16[] memory collateralFactors = new uint16[](1);
        collateralFactors[0] = 150;
        uint16[] memory liquidationThresholds = new uint16[](1);
        liquidationThresholds[0] = 110;
        vm.expectRevert("MR_AA: LENGTH_MISMATCH");
        aTokenPricingModule.setAssetInformation(address(aEth), collateralFactors, liquidationThresholds);
        vm.stopPrank();
    }

    function testSuccess_setAssetInformation_OwnerAddsAssetWithEmptyListCreditRatings() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_setAssetInformation_OwnerAddsAssetWithFullListRiskVariables() public {
        vm.startPrank(creatorAddress);
        uint16[] memory collateralFactors = new uint16[](2);
        collateralFactors[0] = 150;
        collateralFactors[1] = 150;
        uint16[] memory liquidationThresholds = new uint16[](2);
        liquidationThresholds[0] = 110;
        liquidationThresholds[1] = 110;
        aTokenPricingModule.setAssetInformation(address(aEth), collateralFactors, liquidationThresholds);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_OwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_isWhiteListed() public {
        vm.startPrank(creatorAddress);

        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.isWhiteListed(address(aEth), 0));
    }

    function testSuccess_isWhiteListed_Negative(address randomAsset) public {
        assertTrue(!aTokenPricingModule.isWhiteListed(randomAsset, 0));
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = aTokenPricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue(uint256 rateEthToUsdNew, uint256 amountEth) public {
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);

        if (rateEthToUsdNew == 0) {
            vm.assume(uint256(amountEth) <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                uint256(amountEth)
                    <= type(uint256).max / Constants.WAD * 10 ** Constants.oracleEthToUsdDecimals / uint256(rateEthToUsdNew)
            );
        }

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateEthToUsdNew) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
        ) / 10 ** Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency) = aTokenPricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testRevert_getValue_Overflow(uint256 rateEthToUsdNew, uint256 amountEth) public {
        vm.assume(rateEthToUsdNew <= uint256(type(int256).max));
        vm.assume(rateEthToUsdNew <= type(uint256).max / Constants.WAD);
        vm.assume(rateEthToUsdNew > 0);

        vm.assume(
            uint256(amountEth)
                > type(uint256).max / Constants.WAD * 10 ** Constants.oracleEthToUsdDecimals / uint256(rateEthToUsdNew)
        );

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsdNew));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        aTokenPricingModule.setAssetInformation(address(aEth), emptyListUint16, emptyListUint16);
        vm.stopPrank();

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        aTokenPricingModule.getValue(getValueInput);
    }
}
