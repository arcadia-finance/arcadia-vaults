/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "./fixtures/ArcadiaVaultsFixture.f.sol";

import { ERC4626Mock } from "../mockups/ERC4626Mock.sol";
import { StandardERC4626PricingModule } from "../PricingModules/StandardERC4626PricingModule.sol";

contract standardERC4626PricingModuleTest is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ERC4626Mock public ybEth;
    ERC4626Mock public ybSnx;
    ERC4626Mock public ybLink;
    StandardERC4626PricingModule public standardERC4626PricingModule;

    //this is a before
    constructor() DeployArcadiaVaults() {
        vm.prank(tokenCreatorAddress);
        ybEth = new ERC4626Mock(eth, "ybETH Mock", "mybETH", uint8(Constants.ethDecimals));
    }

    //this is a before each
    function setUp() public {
        vm.startPrank(creatorAddress);
        mainRegistry = new mainRegistryExtension(address(factory));
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

        standardERC4626PricingModule = new StandardERC4626PricingModule(
            address(mainRegistry),
            address(oracleHub),
            address(standardERC20PricingModule)
        );

        mainRegistry.addPricingModule(address(standardERC20PricingModule));
        mainRegistry.addPricingModule(address(standardERC4626PricingModule));

        standardERC20PricingModule.addAsset(address(eth), oracleEthToUsdArr, emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOYMENT
    //////////////////////////////////////////////////////////////*/

    function testSuccess_deployment() public {
        assertEq(standardERC4626PricingModule.mainRegistry(), address(mainRegistry));
        assertEq(standardERC4626PricingModule.oracleHub(), address(oracleHub));
        assertEq(standardERC4626PricingModule.erc20PricingModule(), address(standardERC20PricingModule));
    }

    /*///////////////////////////////////////////////////////////////
                        ASSET MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    function testRevert_addAsset_NonOwner(address unprivilegedAddress_) public {
        vm.assume(unprivilegedAddress_ != creatorAddress);
        vm.startPrank(unprivilegedAddress_);
        vm.expectRevert("UNAUTHORIZED");
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_DecimalsDontMatch(uint8 decimals) public {
        vm.assume(decimals != uint8(Constants.ethDecimals));
        vm.assume(decimals <= 20);
        vm.prank(tokenCreatorAddress);
        ybEth = new ERC4626Mock(eth, "aETH Mock", "maETH", decimals);

        vm.startPrank(creatorAddress);
        vm.expectRevert("PM4626_AA: Decimals don't match");
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();
    }

    function testRevert_addAsset_OverwriteExistingAsset() public {
        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.expectRevert("PM4626_AA: already added");
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(standardERC4626PricingModule.inPricingModule(address(ybEth)));
    }

    function testSuccess_addAsset_EmptyListRiskVariables() public {
        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        assertTrue(standardERC4626PricingModule.inPricingModule(address(ybEth)));
        assertEq(standardERC4626PricingModule.assetsInPricingModule(0), address(ybEth));
        (uint64 assetUnit, address underlyingAsset, address[] memory oracles) =
            standardERC4626PricingModule.getAssetInformation(address(ybEth));
        assertEq(assetUnit, 10 ** uint8(Constants.ethDecimals));
        assertEq(underlyingAsset, address(eth));
        for (uint256 i; i < oracleEthToUsdArr.length; ++i) {
            assertEq(oracles[i], oracleEthToUsdArr[i]);
        }
        assertTrue(standardERC4626PricingModule.isAllowListed(address(ybEth), 0));
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

        standardERC4626PricingModule.addAsset(address(ybEth), riskVars_, type(uint128).max);
        vm.stopPrank();

        assertTrue(standardERC4626PricingModule.inPricingModule(address(ybEth)));
    }

    /*///////////////////////////////////////////////////////////////
                        WHITE LIST MANAGEMENT
    ///////////////////////////////////////////////////////////////*/

    /*///////////////////////////////////////////////////////////////
                          PRICING LOGIC
    ///////////////////////////////////////////////////////////////*/

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsUsd(uint128 amountEth) public {
        //Does not test on overflow, test to check if function correctly returns value in USD
        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        stdstore.target(address(ybEth)).sig(ybEth.totalSupply.selector).checked_write(1);

        //Cheat balance of
        stdstore.target(address(eth)).sig(ybEth.balanceOf.selector).with_key(address(ybEth)).checked_write(amountEth);

        uint256 expectedValueInUsd = (amountEth * rateEthToUsd * Constants.WAD)
            / 10 ** (Constants.oracleEthToUsdDecimals + Constants.ethDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybEth),
            assetId: 0,
            assetAmount: 1, //100% of the shares
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnBaseCurrencyValueWhenBaseCurrencyIsNotUsd(uint128 amountSnx) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.prank(tokenCreatorAddress);
        ybSnx = new ERC4626Mock(snx, "ybSNX Mock", "mybSNX", uint8(Constants.snxDecimals));

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(snx), oracleSnxToEthEthToUsd, emptyRiskVarInput, type(uint128).max);
        standardERC4626PricingModule.addAsset(address(ybSnx), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        stdstore.target(address(ybSnx)).sig(ybSnx.totalSupply.selector).checked_write(1);

        //Cheat balance of
        stdstore.target(address(snx)).sig(snx.balanceOf.selector).with_key(address(ybSnx)).checked_write(amountSnx);

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = (amountSnx * rateSnxToEth * Constants.WAD)
            / 10 ** (Constants.oracleSnxToEthDecimals + Constants.snxDecimals);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybSnx),
            assetId: 0,
            assetAmount: 1, //100% of the shares
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ReturnUsdValueWhenBaseCurrencyIsNotUsd(uint128 amountLink) public {
        //Does not test on overflow, test to check if function correctly returns value in BaseCurrency
        vm.prank(tokenCreatorAddress);
        ybLink = new ERC4626Mock(link, "ybLINK Mock", "mybLINK", uint8(Constants.linkDecimals));

        vm.startPrank(creatorAddress);
        standardERC20PricingModule.addAsset(address(link), oracleLinkToUsdArr, emptyRiskVarInput, type(uint128).max);
        standardERC4626PricingModule.addAsset(address(ybLink), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        stdstore.target(address(ybLink)).sig(ybLink.totalSupply.selector).checked_write(1);

        //Cheat balance of
        stdstore.target(address(link)).sig(link.balanceOf.selector).with_key(address(ybLink)).checked_write(amountLink);

        uint256 expectedValueInUsd = (amountLink * rateLinkToUsd * Constants.WAD)
            / 10 ** (Constants.oracleLinkToUsdDecimals + Constants.linkDecimals);
        uint256 expectedValueInBaseCurrency = 0;

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybLink),
            assetId: 0,
            assetAmount: 1, //100% of the shares
            baseCurrency: uint8(Constants.EthBaseCurrency)
        });

        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue_ZeroTotalSupply(uint256 rateEthToUsd_, uint256 totalAssets) public {
        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);

        uint256 expectedValueInUsd = 0;
        uint256 expectedValueInBaseCurrency = 0;

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat balance of
        uint256 slot2 = stdstore.target(address(eth)).sig(eth.balanceOf.selector).with_key(address(ybEth)).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybEth),
            assetId: 0,
            assetAmount: 0,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testSuccess_getValue(uint256 rateEthToUsd_, uint256 shares, uint256 totalSupply, uint256 totalAssets)
        public
    {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);

        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);
        if (totalAssets > 0) {
            vm.assume(shares <= type(uint256).max / totalAssets);
        }
        if (rateEthToUsd_ == 0) {
            vm.assume(shares * totalAssets / totalSupply <= type(uint256).max / Constants.WAD);
        } else {
            vm.assume(
                shares * totalAssets / totalSupply
                    <= type(uint256).max / Constants.WAD * 10 ** Constants.oracleEthToUsdDecimals / uint256(rateEthToUsd_)
            );
        }

        uint256 expectedValueInUsd = (shares * totalAssets / totalSupply)
            * (Constants.WAD * rateEthToUsd_ / 10 ** Constants.oracleEthToUsdDecimals) / 10 ** Constants.ethDecimals;
        uint256 expectedValueInBaseCurrency = 0;

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        uint256 slot = stdstore.target(address(ybEth)).sig(ybEth.totalSupply.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedTotalSupply = bytes32(abi.encode(totalSupply));
        vm.store(address(ybEth), loc, mockedTotalSupply);

        //Cheat balance of
        uint256 slot2 = stdstore.target(address(eth)).sig(eth.balanceOf.selector).with_key(address(ybEth)).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybEth),
            assetId: 0,
            assetAmount: shares,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });
        (uint256 actualValueInUsd, uint256 actualValueInBaseCurrency,,) =
            standardERC4626PricingModule.getValue(getValueInput);

        assertEq(actualValueInUsd, expectedValueInUsd);
        assertEq(actualValueInBaseCurrency, expectedValueInBaseCurrency);
    }

    function testRevert_getValue_Overflow(
        uint256 rateEthToUsd_,
        uint256 shares,
        uint256 totalSupply,
        uint256 totalAssets
    ) public {
        vm.assume(shares <= totalSupply);
        vm.assume(totalSupply > 0);
        vm.assume(totalAssets > 0);
        vm.assume(rateEthToUsd_ > 0);

        vm.assume(rateEthToUsd_ <= type(uint256).max / Constants.WAD);
        vm.assume(shares <= type(uint256).max / totalAssets);

        vm.assume(
            shares * totalAssets / totalSupply
                > type(uint256).max / Constants.WAD * 10 ** Constants.oracleEthToUsdDecimals / uint256(rateEthToUsd_)
        );

        vm.startPrank(oracleOwner);
        oracleEthToUsd.transmit(int256(rateEthToUsd_));
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        standardERC4626PricingModule.addAsset(address(ybEth), emptyRiskVarInput, type(uint128).max);
        vm.stopPrank();

        //Cheat totalSupply
        uint256 slot = stdstore.target(address(ybEth)).sig(ybEth.totalSupply.selector).find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedTotalSupply = bytes32(abi.encode(totalSupply));
        vm.store(address(ybEth), loc, mockedTotalSupply);

        //Cheat balance of
        uint256 slot2 = stdstore.target(address(eth)).sig(ybEth.balanceOf.selector).with_key(address(ybEth)).find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 mockedBalanceOf = bytes32(abi.encode(totalAssets));
        vm.store(address(eth), loc2, mockedBalanceOf);

        PricingModule.GetValueInput memory getValueInput = PricingModule.GetValueInput({
            asset: address(ybEth),
            assetId: 0,
            assetAmount: shares,
            baseCurrency: uint8(Constants.UsdBaseCurrency)
        });

        //Arithmetic overflow.
        vm.expectRevert(bytes(""));
        standardERC4626PricingModule.getValue(getValueInput);
    }
}
