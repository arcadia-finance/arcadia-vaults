/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.13;

import "../fixtures/ArcadiaVaultsFixture.f.sol";

import { LendingPool, DebtToken, ERC20, DataTypes } from "../../../lib/arcadia-lending/src/LendingPool.sol";
import { Tranche } from "../../../lib/arcadia-lending/src/Tranche.sol";

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

        interleave.mint(tokenCreatorAddress, 2, 100_000);
        interleave.mint(tokenCreatorAddress, 3, 100_000);
        interleave.mint(tokenCreatorAddress, 4, 100_000);
        interleave.mint(tokenCreatorAddress, 5, 100_000);

        genericStoreFront = new ERC1155Mock("Generic Storefront Mock", "mGSM");
        genericStoreFront.mint(tokenCreatorAddress, 1, 100_000);
        genericStoreFront.mint(tokenCreatorAddress, 2, 100_000);
        genericStoreFront.mint(tokenCreatorAddress, 3, 100_000);
        genericStoreFront.mint(tokenCreatorAddress, 4, 100_000);
        genericStoreFront.mint(tokenCreatorAddress, 5, 100_000);

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
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        interleave.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            1,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            2,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            3,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            4,
            100_000,
            "0x0000000000000000000000000000000000000000000000000000000000000000"
        );
        genericStoreFront.safeTransferFrom(
            tokenCreatorAddress,
            vaultOwner,
            5,
            100_000,
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
                quoteAssetBaseCurrency: uint8(Constants.EthBaseCurrency),
                baseAsset: "GenStoreFront",
                quoteAsset: "ETH",
                oracle: address(oracleGenericStoreFrontToEth),
                baseAssetAddress: address(genericStoreFront),
                quoteAssetIsBaseCurrency: true,
                isActive: true
            })
        );

        floorERC721PricingModule.addAsset(
            address(mayc), 0, type(uint256).max, oracleMaycToUsdArr, riskVars, type(uint128).max
        );
        floorERC1155PricingModule.addAsset(
            address(genericStoreFront), 1, oracleGenericStoreFrontToEthEthToUsd, riskVars, type(uint128).max
        );
        vm.stopPrank();

        vm.startPrank(creatorAddress);
        liquidator = new Liquidator(address(factory));

        pool = new LendingPool(ERC20(address(dai)), creatorAddress, address(factory), address(liquidator));
        pool.setVaultVersion(1, true);
        liquidator.setAuctionCurveParameters(3600, 14_400);

        debt = DebtToken(address(pool));

        tranche = new Tranche(address(pool), "Senior", "SR");
        pool.addTranche(address(tranche), 50, 0);
        vm.stopPrank();

        vm.prank(liquidityProvider);
        dai.approve(address(pool), type(uint256).max);

        vm.prank(address(tranche));
        pool.depositInLendingPool(type(uint120).max, liquidityProvider);
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
            0,
            address(0)
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
