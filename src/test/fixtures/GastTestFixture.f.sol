/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "../fixtures/ArcadiaVaultsFixture.f.sol";

import {LendingPool, DebtToken, ERC20, DataTypes} from "../../../lib/arcadia-lending/src/LendingPool.sol";
import {Tranche} from "../../../lib/arcadia-lending/src/Tranche.sol";

abstract contract GasTestFixture is DeployArcadiaVaults {
    using stdStorage for StdStorage;

    ERC1155Mock public genericStoreFront;
    ArcadiaOracle public oracleGenericStoreFrontToEth;

    LendingPool pool;
    Tranche tranche;
    DebtToken debt;

    address public liquidatorBot = address(8);
    address public vaultBuyer = address(9);

    uint256 rateGenericStoreFrontToEth = 1 * 10 ** (8);
    address[] public oracleGenericStoreFrontToEthEthToUsd = new address[](2);

    uint16 public collFactor;
    uint16 public liqTresh;

    address[] public s_assetAddresses;
    uint256[] public s_assetIds;
    uint256[] public s_assetAmounts;
    uint256[] public s_assetTypes;

    // EVENTS
    event Transfer(address indexed from, address indexed to, uint256 amount);

    //this is a before
    constructor() DeployArcadiaVaults() {
        //Deploy and mint tokens
        vm.startPrank(tokenCreatorAddress);
        bayc.mint(tokenCreatorAddress, 4);
        bayc.mint(tokenCreatorAddress, 5);
        bayc.mint(tokenCreatorAddress, 6);
        bayc.mint(tokenCreatorAddress, 7);
        bayc.mint(tokenCreatorAddress, 8);
        bayc.mint(tokenCreatorAddress, 9);
        bayc.mint(tokenCreatorAddress, 10);
        bayc.mint(tokenCreatorAddress, 11);
        bayc.mint(tokenCreatorAddress, 12);

        mayc.mint(tokenCreatorAddress, 1);
        mayc.mint(tokenCreatorAddress, 2);
        mayc.mint(tokenCreatorAddress, 3);
        mayc.mint(tokenCreatorAddress, 4);
        mayc.mint(tokenCreatorAddress, 5);
        mayc.mint(tokenCreatorAddress, 6);
        mayc.mint(tokenCreatorAddress, 7);
        mayc.mint(tokenCreatorAddress, 8);
        mayc.mint(tokenCreatorAddress, 9);

        dickButs.mint(tokenCreatorAddress, 1);
        dickButs.mint(tokenCreatorAddress, 2);

        interleave.mint(tokenCreatorAddress, 2, 100000);
        interleave.mint(tokenCreatorAddress, 3, 100000);
        interleave.mint(tokenCreatorAddress, 4, 100000);
        interleave.mint(tokenCreatorAddress, 5, 100000);

        genericStoreFront = new ERC1155Mock("Generic Storefront Mock", "mGSM");
        genericStoreFront.mint(tokenCreatorAddress, 1, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 2, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 3, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 4, 100000);
        genericStoreFront.mint(tokenCreatorAddress, 5, 100000);

        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 4);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 5);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 6);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 7);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 8);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 9);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 10);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 11);
        bayc.transferFrom(tokenCreatorAddress, vaultOwner, 12);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 1);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 2);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 3);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 4);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 5);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 6);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 7);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 8);
        mayc.transferFrom(tokenCreatorAddress, vaultOwner, 9);
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            2,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            2,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        vm.stopPrank();

        //Deploi Oracles
        oracleGenericStoreFrontToEth =
            arcadiaOracleFixture.initMockedOracle(uint8(10), "GenericStoreFront / ETH", rateGenericStoreFrontToEth);

        oracleGenericStoreFrontToEthEthToUsd[0] = address(oracleGenericStoreFrontToEth);
        oracleGenericStoreFrontToEthEthToUsd[1] = address(oracleEthToUsd);

        vm.prank(oracleOwner);
        oracleGenericStoreFrontToEth.transmit(int256(rateGenericStoreFrontToEth));

        //Deploy Arcadia Vaults contracts
        vm.startPrank(creatorAddress);
        oracleHub.addOracle(
            OracleHub.OracleInformation({
                oracleUnit: uint64(10 ** 10),
                baseAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                quoteAsset: "GenericStoreFront",
                baseAsset: "ETH",
                oracle: address(oracleGenericStoreFrontToEth),
                quoteAssetAddress: address(genericStoreFront),
                baseAssetIsBaseCurrency: true
            })
        );

        collFactor = mainRegistry.DEFAULT_COLLATERAL_FACTOR();
        liqTresh = mainRegistry.DEFAULT_LIQUIDATION_THRESHOLD();
        uint16[] memory collateralFactors = new uint16[](3);
        collateralFactors[0] = collFactor;
        collateralFactors[1] = collFactor;
        collateralFactors[2] = collFactor;
        uint16[] memory liquidationThresholds = new uint16[](3);
        liquidationThresholds[0] = liqTresh;
        liquidationThresholds[1] = liqTresh;
        liquidationThresholds[2] = liqTresh;

        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleEthToUsdArr,
                assetUnit: uint64(10 ** Constants.ethDecimals),
                assetAddress: address(eth)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleLinkToUsdArr,
                assetUnit: uint64(10 ** Constants.linkDecimals),
                assetAddress: address(link)
            }),
            collateralFactors,
            liquidationThresholds
        );
        standardERC20PricingModule.setAssetInformation(
            StandardERC20PricingModule.AssetInformation({
                oracleAddresses: oracleSnxToEthEthToUsd,
                assetUnit: uint64(10 ** Constants.snxDecimals),
                assetAddress: address(snx)
            }),
            collateralFactors,
            liquidationThresholds
        );

        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWbaycToEthEthToUsd,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(bayc)
            }),
            collateralFactors,
            liquidationThresholds
        );
        floorERC721PricingModule.setAssetInformation(
            FloorERC721PricingModule.AssetInformation({
                oracleAddresses: oracleWmaycToUsdArr,
                idRangeStart: 0,
                idRangeEnd: type(uint256).max,
                assetAddress: address(mayc)
            }),
            collateralFactors,
            liquidationThresholds
        );
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleInterleaveToEthEthToUsd,
                id: 1,
                assetAddress: address(interleave)
            }),
            collateralFactors,
            liquidationThresholds
        );
        floorERC1155PricingModule.setAssetInformation(
            FloorERC1155PricingModule.AssetInformation({
                oracleAddresses: oracleGenericStoreFrontToEthEthToUsd,
                id: 1,
                assetAddress: address(genericStoreFront)
            }),
            collateralFactors,
            liquidationThresholds
        );
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(
            address(factory),
            address(mainRegistry)
        );
        liquidator.setFactory(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory));
        pool.setLiquidator(address(liquidator));

        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint128).max, liquidityProvider);
    }

    function setUp() public virtual {
        vm.prank(vaultOwner);
        proxyAddr = factory.createVault(
            uint256(
                keccak256(
                    abi.encodeWithSignature(
                        "doRandom(uint256,uint256,bytes32)", block.timestamp, block.number, blockhash(block.number)
                    )
                )
            ),
            0
        );
        proxy = Vault(proxyAddr);

        vm.roll(1); //increase block for random salt

        vm.startPrank(vaultOwner);
        proxy.openTrustedMarginAccount(address(pool));
        dai.approve(address(pool), type(uint256).max);

        bayc.setApprovalForAll(address(proxy), true);
        mayc.setApprovalForAll(address(proxy), true);
        dickButs.setApprovalForAll(address(proxy), true);
        interleave.setApprovalForAll(address(proxy), true);
        genericStoreFront.setApprovalForAll(address(proxy), true);
        eth.approve(address(proxy), type(uint256).max);
        link.approve(address(proxy), type(uint256).max);
        snx.approve(address(proxy), type(uint256).max);
        safemoon.approve(address(proxy), type(uint256).max);
        vm.stopPrank();

        vm.prank(vaultBuyer);
        dai.approve(address(liquidator), type(uint256).max);

        vm.prank(tokenCreatorAddress);
        eth.mint(vaultOwner, 1e18);
    }
}