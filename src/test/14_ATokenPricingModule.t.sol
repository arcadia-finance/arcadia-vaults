/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import {ATokenMock} from "../mockups/ATokenMock.sol";
import {ATokenPricingModule} from "../PricingModules/ATokenPricingModule.sol";

contract aTokenPricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ATokenMock public aEth;
    ATokenMock public aSnx;
    ATokenMock public aLink;
    ATokenPricingModule public aTokenPricingModule;

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.prank(tokenCreatorAddress);
        aEth = new ATokenMock(address(eth), "aETH Mock", "maETH", uint8(Constants.ethDecimals));
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
            }), address(factory)
        );
        mainRegistry.addBaseCurrency(
            MainRegistry.BaseCurrencyInformation({
                baseCurrencyToUsdOracleUnit: uint64(10 ** Constants.oracleDaiToUsdDecimals),
                assetAddress: address(dai),
                baseCurrencyToUsdOracle: address(oracleDaiToUsd),
                baseCurrencyLabel: "DAI",
                baseCurrencyUnitCorrection: uint64(10 ** (18 - Constants.daiDecimals))
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
            address(oracleHub),
            address(standardERC20PricingModule)
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(aTokenPricingModule));

        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function testSuccess_deployment() public {
        assertEq(aTokenPricingModule.mainRegistry(), address(mainRegistry));
        assertEq(aTokenPricingModule.oracleHub(), address(oracleHub));
        assertEq(aTokenPricingModule.erc20PricingModule(), address(standardERC20PricingModule));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("Ownable: caller is not the owner");
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_DecimalsDontMatch(uint8 decimals) public {
        vm.assume(decimals != uint8(Constants.ethDecimals));
        vm.assume(decimals <= 20);
        vm.prank(tokenCreatorAddress);
        aEth = new ATokenMock(address(eth), "aETH Mock", "maETH", decimals);

        vm.startPrank(creatorAddress);
        vm.expectRevert("PMAT_AA: Decimals don't match");
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);

        vm.expectRevert("PMAT_AA: already added");
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_ExposureNotInLimits() public {
        // Given: All necessary contracts deployed on setup
        // When: creatorAddress calls addAsset with maxExposure exceeding type(uint128).max
        // Then: addAsset should revert with "PMAT_AA: Max Exposure not in limits"
        vm.startPrank(creatorAddress);
        vm.expectRevert("PMAT_AA: Max Exposure not in limits");
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, uint256(type(uint128).max) + 1);
        vm.stopPrank();
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
        assertEq(aTokenPricingModule.assetsInPricingModule(0), address(aEth));
        (uint64 assetUnit, address underlyingAsset, address[] memory oracles) =
            aTokenPricingModule.getAssetInformation(address(aEth));
        assertEq(assetUnit, 10 ** uint8(Constants.ethDecimals));
        assertEq(underlyingAsset, address(eth));
        for (uint256 i; i < oracleEthToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleEthToUsdArr[i]);
        }
        assertTrue(aTokenPricingModule.isWhiteListed(address(aEth), 0));
    }

    function testSuccess_addAsset_NonFullListRiskVariables() public {
        vm.startPrank(creatorAddress);
        PricingModule.RiskVarInput[] memory riskVars_ = new PricingModule.RiskVarInput[](1);
        riskVars_[0] = PricingModule.RiskVarInput({
            baseCurrency: 0,
            asset: address(0),
            collateralFactor: collateralFactor,
            liquidationFactor: liquidationFactor
        });

        aTokenPricingModule.addAsset(address(aEth), riskVars_, type(uint128).max);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    function testSuccess_addAsset_FullListRiskVariables() public {
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(address(aEth), riskVars, type(uint128).max);
        vm.stopPrank();

        assertTrue(aTokenPricingModule.inPricingModule(address(aEth)));
    }

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = aTokenPricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(uint128 amountSnx) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.prank(tokenCreatorAddress);
        aSnx = new ATokenMock(address(snx), "aSNX Mock", "maSNX", uint8(Constants.snxDecimals));

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, emptyRiskVarInput, type(uint128).max);
        aTokenPricingModule.addAsset(address(aSnx), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (amountSnx * rateSnxToEth * Constants.WAD)
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(aSnx),
            assetId: 0,
            assetAmount: amountSnx,
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) = aTokenPricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountLink) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.prank(tokenCreatorAddress);
        aLink = new ATokenMock(address(link), "aLINK Mock", "maLINK", uint8(Constants.linkDecimals));

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);
        aTokenPricingModule.addAsset(address(aLink), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (amountLink * rateLinkToUsd * Constants.WAD)
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(aLink),
            assetId: 0,
            assetAmount: amountLink,
            baseCurrency: uint8(Constants.EthBaseCurrency)
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
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        uint256 expectedValueInUsd = (
            ((Constants.WAD * rateEthToUsdNew) / 10 ** Constants.oracleEthToUsdDecimals) * amountEth
        ) / 10 ** Constants.ethDecimals;

        emit log_named_uint("(Constants.WAD * rateEthToUsdNew)", (Constants.WAD * rateEthToUsdNew));
        emit log_named_uint("Constants.oracleEthToUsdDecimals", Constants.oracleEthToUsdDecimals);

        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(aEth),
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
        aTokenPricingModule.addAsset(address(aEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(aEth),
            assetId: 0,
            assetAmount: amountEth,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        aTokenPricingModule.getValue(getValueInput);
    }
}
