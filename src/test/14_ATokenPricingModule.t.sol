/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import "../mockups/ATokenMock.sol";
import "../AssetRegistry/ATokenPricingModule.sol";

contract aTokenPricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ATokenMock public aEth;
    ATokenPricingModule public aTokenPricingModule;

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.prank(tokenCreatorAddress);
        aEth = new ATokenMock   (address(eth), "aETH Mock", "maETH");
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
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
            }),
            new MainRegistry.AssetRisk[](0)
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleEthToUsdDecimals),
                assetAddress: address(eth),
                baseCurrencyToUsdOracle: address(oracleEthToUsd),
                baseCurrencyLabel: "ETH",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.ethDecimals))
            }),
            new MainRegistry.AssetRisk[](0)
        );

        standardERC20PricingModule = new StandardERC20PricingModuleExtended( //ToDo: remove extension
            address(mainRegistry),
            address(oracleHub)
        );

        aTokenPricingModule = new ATokenPricingModule(
            address(mainRegistry),
            address(oracleHub)
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(aTokenPricingModule));

        standardERC20PricingModule.addAsset(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16
            })
        );
        vm.stopPrank();
    }

    function testRevert_addAsset_NonOwnerAddsAsset(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();
    }

    function testRevert_addAsset_OwnerAddsAssetWithWrongNumberOfRiskVariables() public {
        vm.startPrank(creatorAddress);
        uint16[] memory collateralFactors = new uint16[](1);
        collateralFactors[0] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16[] memory liquidationThresholds = new uint16[](1);
        liquidationThresholds[0] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;

        vm.expectRevert("APM_SRV: LENGTH_MISMATCH");
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: collateralFactors,
                assetLiquidationThresholds: liquidationThresholds,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();
    }

    function testSuccess_addAsset_OwnerAddsAssetWithEmptyListRiskVariables() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_addAsset_OwnerAddsAssetWithFullListRiskVariables() public {
        vm.startPrank(creatorAddress);
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        collateralFactors[1] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        collateralFactors[2] = RiskConstants.DEFAULT_COLLATERAL_FACTOR;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        liquidationThresholds[1] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        liquidationThresholds[2] = RiskConstants.DEFAULT_LIQUIDATION_THRESHOLD;
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: collateralFactors,
                assetLiquidationThresholds: liquidationThresholds,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_OwnerOverwritesExistingAsset() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_isWhiteListed() public {
        vm.startPrank(creatorAddress);

        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();

        assertTrue(aTokenPricingModule.isWhiteListed(address(aEth), 0));
    }

    function testSuccess_isWhiteListed_Negative(address randomAsset) public {
        assertTrue(!aTokenPricingModule.isWhiteListed(randomAsset, 0));
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
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

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = aTokenPricingModule.getValue(getValueInput);

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
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateEthToUsdNew) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
        ) / 10 ** Constants.ethDecimals;

        emit log_named_uint("(Constants.WAD * rateEthToUsdNew)", (Constants.WAD * rateEthToUsdNew));
        emit log_named_uint("Constants.oracleEthToUsdDecimals", Constants.oracleEthToUsdDecimals);

        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            assetAddress: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = aTokenPricingModule.getValue(getValueInput);

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
        aTokenPricingModule.addAsset(
            ATokenPricingModule.AssetInformation({
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetCollateralFactors: emptyListUint16,
                assetLiquidationThresholds: emptyListUint16,
                assetAddress: address(aEth),
                underlyingAssetUnit: uint64(10 ** Constants.ethDecimals),
                underlyingAsset: address(eth),
                underlyingAssetOracleAddresses: oracleEthToUsdArr
            })
        );
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
