/** 
    Created by Arcadia Finance
    https://www.arcadia.finance

    SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >0.8.10;

import "./../8_Vault.t.sol";
import "../../../lib/forge-std/src/Test.sol";

import "../../Proxy.sol";
import "../../AssetRegistry/MainRegistry.sol";
import "../../InterestRateModule.sol";
import "../../Liquidator.sol";
import "../../OracleHub.sol";
import "../../utils/Constants.sol";

import "../../paperTradingCompetition/FactoryPaperTrading.sol";
import "../../paperTradingCompetition/VaultPaperTrading.sol";
import "../../paperTradingCompetition/StablePaperTrading.sol";
import "../../paperTradingCompetition/ERC20PaperTrading.sol";
import "../../AssetRegistry/StandardERC20SubRegistry.sol";
import "../../paperTradingCompetition/TokenShop.sol";
import "../../ArcadiaOracle.sol";
import "../fixtures/ArcadiaOracleFixture.f.sol";

contract VaultPaperTradingInheritedTest is vaultTests {
    using stdStorage for StdStorage;

    ArcadiaOracle internal oracleStableUsdToUsd;
    ArcadiaOracle internal oracleStableEthToEth;
    VaultPaperTrading internal vault;
    StablePaperTrading internal stableUsd;
    StablePaperTrading internal stableEth;
    TokenShop internal tokenShop;

    address[] public oracleStableUsdToUsdArr = new address[](1);
    address[] public oracleStableEthToUsdArr = new address[](2);

    //this is a before
    constructor() vaultTests() {
        // The rest of the initialization for the tests
        vm.startPrank(creatorAddress);
        factoryContr = new FactoryPaperTrading();

        stableUsd = new StablePaperTrading(
            "Arcadia USD Stable Mock",
            "masUSD",
            uint8(Constants.stableDecimals),
            0x0000000000000000000000000000000000000000,
            address(factoryContr)
        );
        stableEth = new StablePaperTrading(
            "Arcadia ETH Stable Mock",
            "masETH",
            uint8(Constants.stableEthDecimals),
            0x0000000000000000000000000000000000000000,
            address(factoryContr)
        );

        // TODO: Fix the stop start prank schema - zekiblue - 30/05/2022
        // One solution can be the pass the vm to the init function and use it!
        // There is no way of double prank
        vm.stopPrank();
        oracleStableUsdToUsd = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableToUsdDecimals),
            "masUSD / USD"
        );
        oracleStableEthToEth = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableEthToEthUnit),
            "masEth / Eth"
        );
        vm.startPrank(creatorAddress);

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

        oracleStableUsdToUsdArr[0] = address(oracleStableUsdToUsd);
        oracleStableEthToUsdArr[0] = address(oracleStableEthToEth);
        oracleStableEthToUsdArr[1] = address(oracleEthToUsd);

        vm.stopPrank();
    }

    //this is a before each
    function setUp() public override {
        vm.startPrank(creatorAddress);
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

        factoryContr.setNewVaultInfo(
            address(mainRegistry),
            address(vault),
            stakeContract,
            address(interestRateModule)
        );
        factoryContr.confirmNewVaultInfo();

        mainRegistry.setFactory(address(factoryContr));

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
        liquidator = new Liquidator(
            0x0000000000000000000000000000000000000000,
            address(mainRegistry)
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

        vm.startPrank(vaultOwner);
        vault = new VaultPaperTrading();
        vm.stopPrank();

        uint256 slot = stdstore
            .target(address(factoryContr))
            .sig(factoryContr.isVault.selector)
            .with_key(address(vault))
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factoryContr), loc, mockedCurrentTokenId);

        vm.startPrank(creatorAddress);
        stableUsd.setLiquidator(address(liquidator));
        stableEth.setLiquidator(address(liquidator));

        tokenShop = new TokenShop(address(mainRegistry));
        vm.stopPrank();

        vm.startPrank(vaultOwner);
        vault.initialize(
            vaultOwner,
            address(mainRegistry),
            uint256(Constants.UsdNumeraire),
            address(stableUsd),
            address(stakeContract),
            address(interestRateModule),
            address(tokenShop)
        );
        vm.stopPrank();
    }

    //input as uint8 to prevent too long lists as fuzz input
    function testShouldFailIfLengthOfListDoesNotMatch(
        uint8 addrLen,
        uint8 idLen,
        uint8 amountLen,
        uint8 typesLen
    ) public override {}

    function testShouldFailIfERC20IsNotWhitelisted(address inputAddr)
        public
        override
    {}

    function testShouldFailIfERC721IsNotWhitelisted(
        address inputAddr,
        uint256 id
    ) public override {}

    function testSingleERC20Deposit(uint16 amount) public override {}

    function testMultipleSameERC20Deposits(uint16 amount) public override {}

    function testSingleERC721Deposit() public override {}

    function testMultipleERC721Deposits() public override {}

    function testSingleERC1155Deposit() public override {}

    function testDepositERC20ERC721(uint8 erc20Amount1, uint8 erc20Amount2)
        public
        override
    {}

    function testDepositERC20ERC721ERC1155(
        uint8 erc20Amount1,
        uint8 erc20Amount2,
        uint8 erc1155Amount
    ) public override {}

    function testDepositOnlyByOwner(address sender) public override {}

    function testWithdrawERC20NoDebt(uint8 baseAmountDeposit) public override {}

    function testTakeCredit(uint8, uint8 baseAmountCredit) public override {
        uint128 amountCredit = uint128(baseAmountCredit * Constants.WAD);
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume((1000000 * Constants.WAD * 100) / _collThres >= amountCredit);

        vm.startPrank(vaultOwner);
        vault.takeCredit(amountCredit);
        vm.stopPrank();

        uint256 expectedValue = 1000000 * Constants.WAD + amountCredit;
        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
        assertEq(vault.getOpenDebt(), amountCredit);
    }

    function testWithdrawERC20fterTakingCredit(
        uint8 baseAmountDeposit,
        uint32 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public override {}

    function testNotAllowWithdrawERC20fterTakingCredit(
        uint8 baseAmountDeposit,
        uint24 baseAmountCredit,
        uint8 baseAmountWithdraw
    ) public override {}

    function testWithrawERC721AfterTakingCredit(
        uint128[] calldata tokenIdsDeposit,
        uint8 baseAmountCredit
    ) public override {}

    function testNotAllowERC721Withdraw(
        uint128[] calldata tokenIdsDeposit,
        uint8 amountsWithdrawn
    ) public override {}

    function testNotAllowedToWithdrawnByNonOwner(
        uint8 depositAmount,
        uint8 withdrawalAmount,
        address sender
    ) public override {}

    function testFetchVaultValue(uint8 depositAmount) public override {}

    function testGetValueGasUsage(
        uint8 depositAmount,
        uint128[] calldata tokenIds
    ) public override {}

    function testGetDebtAtStart() public override {
        uint256 openDebt = vault.getOpenDebt();
        assertEq(openDebt, 0);
    }

    function testGetRemainingCreditAtStart() public override {
        (, uint16 _collThres, , , , ) = vault.debt();
        uint256 expectedRemaining = (1000000 * 10**18 * 100) / _collThres;

        uint256 remainingCredit = vault.getRemainingCredit();
        assertEq(remainingCredit, expectedRemaining);
    }

    function testGetRemainingCredit(uint8 amount) public override {}

    function testGetRemainingCreditAfterTopUp(
        uint8 amountEth,
        uint8 amountLink,
        uint128[] calldata tokenIds
    ) public override {}

    function testGetRemainingCreditAfterTakingCredit(
        uint8 amountEth,
        uint128 amountCredit
    ) public override {}

    function testInitializeWithZeroInterest() public override {
        (
            uint256 _openDebt,
            ,
            ,
            uint64 _yearlyInterestRate,
            uint32 _lastBlock,

        ) = vault.debt();

        assertEq(_openDebt, 0);
        assertEq(_yearlyInterestRate, 0);
        assertEq(_lastBlock, 0);
    }

    function testTakeCreditAsNonOwner(uint8, uint128 amountCredit)
        public
        override
    {
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume((1000000 * 10**18) / _collThres > amountCredit);

        vm.startPrank(unprivilegedAddress);
        vm.expectRevert("You are not the owner");
        vault.takeCredit(amountCredit);
    }

    function testSyncDebtUnchecked(
        uint64 base,
        uint24 deltaBlocks,
        uint128 openDebt
    ) public override {}

    function testGetOpenDebtUnchecked(uint32 blocksToRoll) public override {}

    function testRemainingCreditUnchecked(uint128 amountEth, uint8 factor)
        public
        override
    {}

    function testTransferOwnershipOfVaultByNonOwner(address sender)
        public
        override
    {
        vm.assume(sender != address(factoryContr));
        vm.startPrank(sender);
        vm.expectRevert("VL: Not factory");
        vault.transferOwnership(address(10));
        vm.stopPrank();
    }

    function testTransferOwnership(address to) public override {
        vm.assume(to != address(0));
        Vault vault_m = new Vault();

        uint256 slot2 = stdstore
            .target(address(vault_m))
            .sig(vault_m._registryAddress.selector)
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 newReg = bytes32(abi.encode(address(mainRegistry)));
        vm.store(address(vault_m), loc2, newReg);

        assertEq(address(0), vault_m.owner());
        vm.prank(address(factoryContr));
        vault_m.transferOwnership(to);
        assertEq(to, vault_m.owner());

        vault_m = new Vault();
        vault_m.initialize(
            address(this),
            address(mainRegistry),
            Constants.UsdNumeraire,
            address(stable),
            address(stakeContract),
            address(interestRateModule)
        );
        assertEq(address(this), vault_m.owner());

        vm.prank(address(factoryContr));
        vault_m.transferOwnership(to);
        assertEq(to, vault_m.owner());
    }

    function testTransferOwnershipByNonOwner(address from) public override {
        vm.assume(
            from != address(this) &&
                from != address(0) &&
                from != address(factoryContr)
        );
        Vault vault_m = new Vault();
        address to = address(123456);

        uint256 slot2 = stdstore
            .target(address(vault_m))
            .sig(vault_m._registryAddress.selector)
            .find();
        bytes32 loc2 = bytes32(slot2);
        bytes32 newReg = bytes32(abi.encode(address(mainRegistry)));
        vm.store(address(vault_m), loc2, newReg);

        assertEq(address(0), vault_m.owner());

        vm.startPrank(from);
        vm.expectRevert("VL: Not factory");
        vault_m.transferOwnership(to);
        vm.stopPrank();

        assertEq(address(0), vault_m.owner());

        vault_m = new Vault();
        vault_m.initialize(
            address(this),
            address(mainRegistry),
            Constants.UsdNumeraire,
            address(stable),
            address(stakeContract),
            address(interestRateModule)
        );
        assertEq(address(this), vault_m.owner());

        vm.startPrank(from);
        vm.expectRevert("VL: Not factory");
        vault_m.transferOwnership(to);
        assertEq(address(this), vault_m.owner());
    }

    function testCreateUsdVault() public {
        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testCreateEthVault() public {
        vm.startPrank(vaultOwner);
        vault = new VaultPaperTrading();

        uint256 slot = stdstore
            .target(address(factoryContr))
            .sig(factoryContr.isVault.selector)
            .with_key(address(vault))
            .find();
        bytes32 loc = bytes32(slot);
        bytes32 mockedCurrentTokenId = bytes32(abi.encode(true));
        vm.store(address(factoryContr), loc, mockedCurrentTokenId);

        vault.initialize(
            vaultOwner,
            address(mainRegistry),
            uint256(Constants.EthNumeraire),
            address(stableEth),
            address(stakeContract),
            address(interestRateModule),
            address(tokenShop)
        );
        vm.stopPrank();

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testTakeCreditInsufficientBalance(uint32 baseAmountCredit) public {
        uint128 amountCredit = uint128(baseAmountCredit * Constants.WAD);
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume((1000000 * Constants.WAD * 100) / _collThres < amountCredit);

        vm.startPrank(vaultOwner);
        vm.expectRevert("Cannot take this amount of extra credit!");
        vault.takeCredit(amountCredit);
        vm.stopPrank();
    }

    function testRepayCredit(
        uint16 baseAmountTakeCredit,
        uint16 baseAmountRepayCredit
    ) public {
        uint128 amountTakeCredit = uint128(
            baseAmountTakeCredit * Constants.WAD
        );
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume(
            (1000000 * Constants.WAD * 100) / _collThres >= amountTakeCredit
        );
        vm.assume(baseAmountRepayCredit <= baseAmountTakeCredit);
        uint128 amountRepayCredit = uint128(
            baseAmountRepayCredit * Constants.WAD
        );

        vm.startPrank(vaultOwner);
        vault.takeCredit(amountTakeCredit);
        vault.repayDebt(amountRepayCredit);
        vm.stopPrank();

        uint256 expectedValue = 1000000 *
            Constants.WAD +
            amountTakeCredit -
            amountRepayCredit;
        uint256 actualValue = vault.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
        assertEq(vault.getOpenDebt(), amountTakeCredit - amountRepayCredit);
    }

    function testFailRepayCreditInsufficientBalance(
        uint32 baseAmountTakeCredit,
        uint32 amountOfBlocksToRoll
    ) public {
        uint128 amountTakeCredit = uint128(
            baseAmountTakeCredit * Constants.WAD
        );
        (, uint16 _collThres, , , , ) = vault.debt();
        vm.assume(
            (1000000 * Constants.WAD * 100) / _collThres >= amountTakeCredit
        );

        vm.startPrank(vaultOwner);
        vault.takeCredit(amountTakeCredit);
        vm.roll(block.number + amountOfBlocksToRoll);
        uint256 debt = vault.getOpenDebt();
        vm.assume(debt > 1000000 * Constants.WAD + amountTakeCredit);

        //Arithmetic overflow.
        vault.repayDebt(debt);
        vm.stopPrank();
    }
}

contract VaultPaperTradingNewTest is Test {
    using stdStorage for StdStorage;

    FactoryPaperTrading private factory;
    VaultPaperTrading private vault;
    VaultPaperTrading private proxy;
    address private proxyAddr;
    ERC20PaperTrading private eth;
    OracleHub private oracleHub;
    ArcadiaOracle private oracleEthToUsd;
    ArcadiaOracle private oracleStableUsdToUsd;
    ArcadiaOracle private oracleStableEthToEth;
    MainRegistry private mainRegistry;
    StandardERC20Registry private standardERC20Registry;
    InterestRateModule private interestRateModule;
    StablePaperTrading private stableUsd;
    StablePaperTrading private stableEth;
    Liquidator private liquidator;
    TokenShop private tokenShop;

    address internal creatorAddress = address(1);
    address internal tokenCreatorAddress = address(2);
    address internal oracleOwner = address(3);
    address internal unprivilegedAddress = address(4);
    address internal stakeContract = address(5);
    address internal vaultOwner = address(6);

    uint256 rateEthToUsd = 3000 * 10**Constants.oracleEthToUsdDecimals;

    address[] public oracleEthToUsdArr = new address[](1);
    address[] public oracleStableUsdToUsdArr = new address[](1);
    address[] public oracleStableEthToUsdArr = new address[](2);
    // Fixtures
    ArcadiaOracleFixture internal arcadiaOracleFixture =
        new ArcadiaOracleFixture(oracleOwner);

    //this is a before
    constructor() {
        // Init the fixtures

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
        liquidator = new Liquidator(address(factory), address(mainRegistry));

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

        vm.prank(tokenCreatorAddress);
        eth = new ERC20PaperTrading(
            "ETH Mock",
            "mETH",
            uint8(Constants.ethDecimals),
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();

        oracleEthToUsd = arcadiaOracleFixture.initMockedOracle(
            uint8(Constants.oracleEthToUsdDecimals),
            "ETH / USD",
            rateEthToUsd
        );

        oracleStableUsdToUsd = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableToUsdDecimals),
            "masUSD / USD"
        );
        oracleStableEthToEth = arcadiaOracleFixture.initStableOracle(
            uint8(Constants.oracleStableEthToEthUnit),
            "masEth / Eth"
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
        mainRegistry.addSubRegistry(address(standardERC20Registry));

        oracleEthToUsdArr[0] = address(oracleEthToUsd);
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
    function setUp() public {}

    function testCreateUsdVault() public {
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

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testCreateEthVault() public {
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
            Constants.EthNumeraire
        );
        proxy = VaultPaperTrading(proxyAddr);

        uint256 expectedValue = 1000000 * Constants.WAD;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
    }

    function testTakeCredit(uint8 baseAmountCredit) public {
        vm.startPrank(vaultOwner);
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

        uint128 amountCredit = uint128(baseAmountCredit * Constants.WAD);
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume((1000000 * Constants.WAD * 100) / _collThres >= amountCredit);

        proxy.takeCredit(amountCredit);

        uint256 expectedValue = 1000000 * Constants.WAD + amountCredit;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
        assertEq(proxy.getOpenDebt(), amountCredit);
    }

    function testRepayCredit(
        uint8 baseAmountTakeCredit,
        uint8 baseAmountRepayCredit
    ) public {
        vm.startPrank(vaultOwner);
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

        uint128 amountTakeCredit = uint128(
            baseAmountTakeCredit * Constants.WAD
        );
        (, uint16 _collThres, , , , ) = proxy.debt();
        vm.assume(
            (1000000 * Constants.WAD * 100) / _collThres >= amountTakeCredit
        );
        vm.assume(baseAmountRepayCredit <= baseAmountTakeCredit);
        uint128 amountRepayCredit = uint128(
            baseAmountRepayCredit * Constants.WAD
        );

        proxy.takeCredit(amountTakeCredit);
        proxy.repayDebt(amountRepayCredit);

        uint256 expectedValue = 1000000 *
            Constants.WAD +
            amountTakeCredit -
            amountRepayCredit;
        uint256 actualValue = proxy.getValue(uint8(Constants.UsdNumeraire));

        assertEq(actualValue, expectedValue);
        assertEq(proxy.getOpenDebt(), amountTakeCredit - amountRepayCredit);
    }
}
