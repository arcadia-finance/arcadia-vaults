/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./../9_Liquidator.t.sol";
import "../../../lib/forge-std/src/Test.sol";

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../paperTradingCompetition/ERC721PaperTrading.sol";
import "../../paperTradingCompetition/ERC1155PaperTrading.sol";
import "../../paperTradingCompetition/LiquidatorPaperTrading.sol";
import "../../paperTradingCompetition/TokenShop.sol";

contract LiquidatorPaperTradingInheritedTest is LiquidatorTest {
    using stdStorage for StdStorage;

    FactoryPaperTrading private factory;
    ArcadiaOracle internal oracleStableUsdToUsd;
    ArcadiaOracle internal oracleStableEthToEth;
    StablePaperTrading internal stableUsd;
    StablePaperTrading internal stableEth;
    TokenShop internal tokenShop;
    VaultPaperTrading internal proxy2;
    address internal proxyAddr2;

    address[] public oracleStableUsdToUsdArr = new address[](1);
    address[] public oracleStableEthToUsdArr = new address[](2);

    constructor() LiquidatorTest() {
        vm.startPrank(creatorAddress);
        factory = new FactoryPaperTrading();

        stableUsd = new StablePaperTrading(
            "Arcadia USD Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            address(factory)
        );
        stableEth = new StablePaperTrading(
            "Arcadia ETH Stable Mock",
            "masETH",
            uint8(Constants.stableEthDecimals),
            0x0000000000000000000000000000000000000000,
            address(factory)
        );

        mainRegistry = new MainRegistry(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: 0,
                assetAddress: 0x0000000000000000000000000000000000000000,
                numeraireToUsdOracle: 0x0000000000000000000000000000000000000000,
                stableAddress: address(stableUsd),
                numeraireLabel: "USD",
                numeraireUnit: 1
            })
        );
        tokenShop = new TokenShop(address(mainRegistry));
        liquidator = new LiquidatorPaperTrading(
            address(factory),
            address(mainRegistry)
        );

        interestRateModule = new InterestRateModule();
        interestRateModule.setBaseInterestRate(5 * 10**16);

        vault = new VaultPaperTrading();
        factory.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factory.confirmNewVaultInfo();

        factory.setLiquidator(address(liquidator));
        factory.setTokenShop(address(tokenShop));
        mainRegistry.setFactory(address(factory));
        tokenShop.setFactory(address(factory));
        stableUsd.setLiquidator(address(liquidator));
        stableEth.setLiquidator(address(liquidator));
        stableUsd.setTokenShop(address(tokenShop));
        stableEth.setTokenShop(address(tokenShop));
        vm.stopPrank();

        vm.startPrank(tokenCreatorAddress);
        eth = new ERC20PaperTrading(
            "ETH Mock",
            "mETH",
            uint8(Constants.ethDecimals),
            address(tokenShop)
        );
        snx = new ERC20PaperTrading(
            "SNX Mock",
            "mSNX",
            uint8(Constants.snxDecimals),
            address(tokenShop)
        );
        link = new ERC20PaperTrading(
            "LINK Mock",
            "mLINK",
            uint8(Constants.linkDecimals),
            address(tokenShop)
        );
        bayc = new ERC721PaperTrading("BAYC Mock", "mBAYC", address(tokenShop));
        wbayc = new ERC20PaperTrading(
            "wBAYC Mock",
            "mwBAYC",
            uint8(Constants.wbaycDecimals),
            address(tokenShop)
        );
        interleave = new ERC1155PaperTrading(
            "Interleave Mock",
            "mInterleave",
            address(tokenShop)
        );
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );
        oracleLinkToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleLinkToUsdDecimals),
            "LINK / USD",
            rateLinkToUsd
        );
        oracleSnxToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleSnxToEthDecimals),
            "SNX / ETH",
            rateSnxToEth
        );
        oracleWbaycToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleWbaycToEthDecimals),
            "WBAYC / ETH",
            rateWbaycToEth
        );
        oracleInterleaveToEth = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleInterleaveToEthDecimals),
            "INTERLEAVE / ETH",
            rateInterleaveToEth
        );

        oracleStableUsdToUsd = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableToUsdDecimals),
            "masUSD / USD",
            address(stableUsd)
        );
        oracleStableEthToEth = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableEthToEthUnit),
            "masEth / Eth",
            address(stableEth)
        );

        vm.startPrank(creatorAddress);
        uint256[] memory emptyList = new uint256[](0);
        mainRegistry.addNumeraire(
            MainRegistry.NumeraireInformation({
                numeraireToUsdOracleUnit: uint64(
                    10**Constants.oracleEthToUsdDecimals
                ),
                assetAddress: address(eth),
                numeraireToUsdOracle: address(oracleEthToUsd),
                stableAddress: address(stableEth),
                numeraireLabel: "ETH",
                numeraireUnit: uint64(10**Constants.ethDecimals)
            }),
            emptyList
        );

        oracleHub = new OracleHub();

        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleEthToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "ETH",
                baseAsset: "USD",
                oracleAddress: address(oracleEthToUsd),
                quoteAssetAddress: address(eth),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleLinkToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "LINK",
                baseAsset: "USD",
                oracleAddress: address(oracleLinkToUsd),
                quoteAssetAddress: address(link),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleSnxToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "SNX",
                baseAsset: "ETH",
                oracleAddress: address(oracleSnxToEth),
                quoteAssetAddress: address(snx),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleWbaycToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "WBAYC",
                baseAsset: "ETH",
                oracleAddress: address(oracleWbaycToEth),
                quoteAssetAddress: address(wbayc),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleInterleaveToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "INTERLEAVE",
                baseAsset: "ETH",
                oracleAddress: address(oracleInterleaveToEth),
                quoteAssetAddress: address(interleave),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableToUsdUnit),
                baseAssetNumeraire: 0,
                quoteAsset: "masUSD",
                baseAsset: "USD",
                oracleAddress: address(oracleStableUsdToUsd),
                quoteAssetAddress: address(stableUsd),
                baseAssetIsNumeraire: true
            })
        );
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(Constants.oracleStableEthToEthUnit),
                baseAssetNumeraire: 1,
                quoteAsset: "masETH",
                baseAsset: "ETH",
                oracleAddress: address(oracleStableEthToEth),
                quoteAssetAddress: address(stableEth),
                baseAssetIsNumeraire: true
            })
        );

        standardERC20Registry = new StandardERC20Registry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC721SubRegistry = new FloorERC721SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        floorERC1155SubRegistry = new FloorERC1155SubRegistry(
            address(mainRegistry),
            address(oracleHub)
        );
        mainRegistry.addSubRegistry(address(standardERC20Registry));
        mainRegistry.addSubRegistry(address(floorERC721SubRegistry));
        mainRegistry.addSubRegistry(address(floorERC1155SubRegistry));

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
        oracleLinkToUsdArr[0] = address(oracleLinkToUsd);
        oracleSnxToEthEthToUsd[0] = address(oracleSnxToEth);
        oracleSnxToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleWbaycToEthEthToUsd[0] = address(oracleWbaycToEth);
        oracleWbaycToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleInterleaveToEthEthToUsd[0] = address(oracleInterleaveToEth);
        oracleInterleaveToEthEthToUsd[1] = address(oracleEthToUsd);
        oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);
        oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
        oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10**Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10**Constants.linkDecimals),
                assetAddress: address(link)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10**Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            emptyList
        );
        floorERC721SubRegistry.setAssetInformation(
            FloorERC721SubRegistry.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            emptyList
        );
        floorERC1155SubRegistry.setAssetInformation(
            FloorERC1155SubRegistry.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 0,
                assetAddress: address(interleave)
            }),
            emptyList
        );

        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleStableUsdToUsdArr,
                assetUnit: uint64(10**Constants.stableDecimals),
                assetAddress: address(stableUsd)
            }),
            emptyList
        );
        standardERC20Registry.setAssetInformation(
            StandardERC20Registry.AssetInformation({
                oracleAddresses: oracleStableEthToUsdArr,
                assetUnit: uint64(10**Constants.stableEthDecimals),
                assetAddress: address(stableEth)
            }),
            emptyList
        );

        vm.stopPrank();
    }

    //this is a before each
    function setUp() public override {
        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)",
                        block.timestamp,
                        block.number,
                        blockhash(block.number)
                    )
                )
            ),
            Constants.UsdNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);
        proxyAddr2 = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)",
                        block.timestamp,
                        block.number,
                        blockhash(block.number)
                    )
                )
            ) + 1,
            Constants.UsdNumeraire
        );
        proxy2 = VaultPaperTrading(proxyAddr2);

        uint256 slot = stdstore
            .target(address(factory))
            .sig(factory.isVault.selector)
            .with_key(address(vault))
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factory), loc, mockedCurrentTokenId);
    }

    function testTransferOwnershipByNonOwner(address from) public override {
        vm.assume(from != address(this) && from != address(factory));

        Liquidator liquidator_m = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
        );
        address to = address(12345);

        assertEq(address(this), liquidator_m.owner());

        vm.startPrank(from);
        vm.expectRevert("Ownable: caller is not the owner");
        liquidator_m.transferOwnership(to);
        assertEq(address(this), liquidator_m.owner());
    }

    function testNotAllowAuctionHealthyVault(uint128, uint128 amountCredit)
        public
        override
    {
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume((1000000 * Constants.WAD * 100) / _collThres >= amountCredit);

        vm.prank(vaultOwner);
        proxy.takeCredit(amountCredit);

        vm.startPrank(liquidatorBot);
        vm.expectRevert("This vault is healthy");
        factory.liquidate(address(proxy), address(proxy2));
        vm.stopPrank();

        assertEq(proxy.life(), 0);
    }

    function testStartAuction(uint128, uint256 newPrice) public override {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);

        buyEthWithLoan(vaultOwner, proxy);

        assertEq(proxy.life(), 0);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice / 2)); //Rounding

        vm.startPrank(liquidatorBot);
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(vaultOwner, address(liquidator));
        factory.liquidate(address(proxy), address(proxy2));
        vm.stopPrank();

        assertEq(proxy.life(), 1);
    }

    function testShowVaultAuctionPrice(uint128, uint256 newPrice)
        public
        override
    {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        vm.assume(newPrice / liqThresProxy < rateEthToUsd / collThresProxy);

        buyEthWithLoan(vaultOwner, proxy);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice / 2)); //Rounding

        vm.startPrank(liquidatorBot);
        factory.liquidate(address(proxy), address(proxy2));
        vm.stopPrank();

        (uint256 vaultPrice, , bool forSale) = liquidator.getPriceOfVault(
            address(proxy),
            0
        );

        assertTrue(!forSale);
        assertEq(vaultPrice, 0);
    }

    function testAuctionPriceDecrease(
        uint128,
        uint256,
        uint64
    ) public override {}

    function testBuyVault(
        uint128,
        uint256,
        uint64
    ) public override {}

    function testWithrawAssetsFromPurchasedVault(
        uint128,
        uint256,
        uint64
    ) public override {}

    function testClaimSingle(uint128) public override {}

    function testClaimMultiple(uint128[] calldata) public override {}

    function testClaimSingleMultipleVaults(uint128) public override {}

    function testClaimSingleHighLife(uint128, uint16) public override {}

    function testClaimSingleWrongLife(
        uint128,
        uint16,
        uint16
    ) public override {}

    function testBreakeven(
        uint128,
        uint256,
        uint64,
        uint8
    ) public override {}

    function testNonVaultLiquidated(address randomAddress) public {
        vm.assume(randomAddress != address(proxy));
        vm.assume(randomAddress != address(proxy2));
        vm.assume(randomAddress != address(vault));
        vm.expectRevert("FTRY_RR: Not a vault");
        factory.liquidate(address(randomAddress), address(proxy2));
    }

    function testNonVaultRewarded(address randomAddress) public {
        vm.assume(randomAddress != address(proxy));
        vm.assume(randomAddress != address(proxy2));
        vm.assume(randomAddress != address(vault));
        vm.expectRevert("FTRY_RR: Not a vault");
        factory.liquidate(address(proxy), address(randomAddress));
    }

    function testSendRewardToLiquidatedVault(uint256 newPrice) public {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        //Take into account that credit taken is automatically re-deposited in the vault
        // -> health factor after taking maximum debt is not equal to the collaterisation treshhold,
        //    When the vault has a current value V, you can take a debt of: V * 100 / collThres
        //    Total value of the Vault is hence: V + V * 100 / collThres = V * (1 + 100 / collThres) = V * (collThres + 100) / collThres
        //    Healt factor is hence: HF = Value / debt = [V * (collThres + 100) / collThres] / [V * 100 / collThres] = (collThres + 100) / 100
        vm.assume(
            newPrice < (rateEthToUsd * liqThresProxy) / (100 + collThresProxy)
        );

        buyEthWithLoan(vaultOwner, proxy);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.startPrank(liquidatorBot);
        vm.expectRevert("FTRY_RR: Can't send rewards to liquidated vaults.");
        factory.liquidate(address(proxy), address(proxy));
        vm.stopPrank();
    }

    function testReceiveReward(uint256 newPrice) public {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        //Take into account that credit taken is automatically re-deposited in the vault
        // -> health factor after taking maximum debt is not equal to the collaterisation treshhold,
        //    When the vault has a current value V, you can take a debt of: V * 100 / collThres
        //    Total value of the Vault is hence: V + V * 100 / collThres = V * (1 + 100 / collThres) = V * (collThres + 100) / collThres
        //    Healt factor is hence: HF = Value / debt = [V * (collThres + 100) / collThres] / [V * 100 / collThres] = (collThres + 100) / 100
        vm.assume(
            newPrice < (rateEthToUsd * liqThresProxy) / (100 + collThresProxy)
        );

        buyEthWithLoan(vaultOwner, proxy);

        vm.prank(oracleOwner);
        oracleEthToUsd.transmit(int256(newPrice));

        vm.startPrank(liquidatorBot);
        factory.liquidate(address(proxy), address(proxy2));
        vm.stopPrank();

        uint256 expectedValue = 1020000 * Constants.WAD;
        uint256 actualValue = proxy2.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testReceiveMaxFiveRewards(uint256 newPrice) public {
        (, uint16 collThresProxy, uint8 liqThresProxy, , , ) = proxy.debt();
        //Take into account that credit taken is automatically re-deposited in the vault
        // -> health factor after taking maximum debt is not equal to the collaterisation treshhold,
        //    When the vault has a current value V, you can take a debt of: V * 100 / collThres
        //    Total value of the Vault is hence: V + V * 100 / collThres = V * (1 + 100 / collThres) = V * (collThres + 100) / collThres
        //    Healt factor is hence: HF = Value / debt = [V * (collThres + 100) / collThres] / [V * 100 / collThres] = (collThres + 100) / 100
        vm.assume(
            newPrice < (rateEthToUsd * liqThresProxy) / (100 + collThresProxy)
        );

        for (uint256 i; i < 6; ) {
            vm.prank(vaultOwner);
            proxyAddr = factory.createVault(
                uint256(
                    keccak256(
                        abi.encodeWithSignature(
                            "doRandom(uint256,uint256,bytes32)",
                            block.timestamp,
                            block.number,
                            blockhash(block.number)
                        )
                    )
                ) +
                    2 +
                    i,
                Constants.UsdNumeraire
            );
            proxy = VaultPaperTrading(proxyAddr);

            buyEthWithLoan(vaultOwner, proxy);

            vm.prank(oracleOwner);
            oracleEthToUsd.transmit(int256(newPrice));

            vm.startPrank(liquidatorBot);
            if (i == 5) {
                vm.expectRevert("VPT_RR: Max rewards received.");
            }
            factory.liquidate(address(proxy), address(proxy2));
            vm.stopPrank();

            vm.prank(oracleOwner);
            oracleEthToUsd.transmit(int256(rateEthToUsd));

            unchecked {
                ++i;
            }
        }

        uint256 expectedValue = 1100000 * Constants.WAD;
        uint256 actualValue = proxy2.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function buyEthWithLoan(address owner, Vault proxyContract) public {
        uint128 amountCredit = uint128(proxy.getRemainingCredit());

        vm.prank(owner);
        proxyContract.takeCredit(amountCredit);

        uint256 usdAmount = 1000000 * Constants.WAD + amountCredit;
        uint256 ethAmount = (10**Constants.ethDecimals *
            usdAmount *
            10**Constants.oracleEthToUsdDecimals) /
            Constants.WAD /
            rateEthToUsd;

        uint256 vaultId = factory.vaultIndex(address(proxyContract));

        address[] memory tokenAddresses = new address[](1);
        tokenAddresses[0] = address(eth);

        uint256[] memory tokenIds = new uint256[](1);
        tokenIds[0] = 0;

        uint256[] memory tokenAmounts = new uint256[](1);
        tokenAmounts[0] = ethAmount;

        uint256[] memory tokenTypes = new uint256[](1);
        tokenTypes[0] = 0;

        TokenShop.TokenInfo memory tokenInfo = TokenShop.TokenInfo(
            tokenAddresses,
            tokenIds,
            tokenAmounts,
            tokenTypes
        );
        vm.prank(owner);
        tokenShop.swapNumeraireForExactTokens(tokenInfo, vaultId);
    }
}
