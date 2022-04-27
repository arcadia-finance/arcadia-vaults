// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../lib/ds-test/src/test.sol";
import "../../lib/forge-std/src/stdlib.sol";
import "../../lib/forge-std/src/console.sol";
import "../../lib/forge-std/src/Vm.sol";

import "../Factory.sol";
import "../Proxy.sol";
import "../Vault.sol";

import "../AssetRegistry/MainRegistry.sol";
import "../tests/ERC20NoApprove.sol";
import "../InterestRateModule.sol";
import "../Liquidator.sol";

import "../utils/Constants.sol";

interface IVaultExtra {

    function life() view external returns (uint256);
    function owner() view external returns (address);
}


contract factoryTest is DSTest {
  using stdStorage for StdStorage;

  Vm private vm = Vm(HEVM_ADDRESS);
  StdStorage private stdstore;

  Factory private factoryContr;
  Vault private vaultContr;
  InterestRateModule private interestContr;
  Liquidator private liquidatorContr;
  MainRegistry private registryContr;
  ERC20NoApprove private erc20Contr;
  address private unprivilegedAddress1 = address(5);


  event VaultCreated(address indexed vaultAddress, address indexed owner, uint256 length);

  //this is a before
  constructor() {
    factoryContr = new Factory();
    vaultContr = new Vault();
    erc20Contr = new ERC20NoApprove(18);
    interestContr = new InterestRateModule();
    liquidatorContr = new Liquidator(address(factoryContr), 0x0000000000000000000000000000000000000000, address(erc20Contr));
		registryContr = new MainRegistry(MainRegistry.NumeraireInformation({numeraireToUsdOracleUnit:0, assetAddress:0x0000000000000000000000000000000000000000, numeraireToUsdOracle:0x0000000000000000000000000000000000000000, numeraireLabel:'USD', numeraireUnit:1}));
    

    factoryContr.setVaultInfo(1, address(registryContr), address(vaultContr), address(erc20Contr), 0x0000000000000000000000000000000000000000, address(interestContr));
    factoryContr.setVaultVersion(1);
    factoryContr.setLiquidator(address(liquidatorContr));

    registryContr.setFactory(address(factoryContr));
  }

   

  //this is a before each
  function setUp() public {
  }

  function getBytecode(address vaultLogic) public pure returns (bytes memory) {
      bytes memory bytecode = type(Proxy).creationCode;

      return abi.encodePacked(bytecode, abi.encode(vaultLogic));
  }

  function getAddress(bytes memory bytecode, uint _salt)
      public
      view
      returns (address)
  {
      bytes32 hash = keccak256(
          abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode))
      );

      // NOTE: cast last 20 bytes of hash to address
      return address(uint160(uint(hash)));
  }


  function testVaultIdStartFromZero() public {
    assertEqDecimal(factoryContr.allVaultsLength(), 0, 1);
  }

  function testDeployNewProxyWithLogic(uint256 salt) public {
    //address toBeDeployedAddr = getAddress(getBytecode(address(vaultContr)), salt);

    uint256 amountBefore = factoryContr.allVaultsLength();

    // vm.expectEmit(true, true, false, true);
    // emit VaultCreated(toBeDeployedAddr, address(this), factoryContr.allVaultsLength() +1);
    address actualDeployed = factoryContr.createVault(salt);
    assertEqDecimal(amountBefore +1, factoryContr.allVaultsLength(), 1);
    assertEqDecimal(IVaultExtra(actualDeployed).life(), 0, 1);

    assertEq(IVaultExtra(actualDeployed).owner(), address(this));
  }

    function testDeployNewProxyWithLogicOwner(uint256 salt, address sender) public {

    uint256 amountBefore = factoryContr.allVaultsLength();
    vm.prank(sender);
    vm.assume(sender != address(0));
    address actualDeployed = factoryContr.createVault(salt);
    assertEqDecimal(amountBefore +1, factoryContr.allVaultsLength(), 1);
    assertEqDecimal(IVaultExtra(actualDeployed).life(), 0, 1);

    assertEq(IVaultExtra(actualDeployed).owner(), address(sender));

    emit log_address(address(1));
  }

  function testOnlyUpgradableByOwner(address sender) public {
    vm.assume(sender != address(this));
    emit log_named_address("sender", sender);
    emit log_named_address("addr(this)", address(this));
    emit log_named_address("owner", factoryContr.owner());
    

    vm.startPrank(sender);
    vm.expectRevert("You are not the owner");
    factoryContr.setVaultVersion(5);
    vm.stopPrank();
  }

  function testTransferVault(address sender) public {
    address receiver = unprivilegedAddress1;
    vm.assume(sender != address(0));


    vm.startPrank(sender);
    address vault = factoryContr.createVault(0);

    //Make sure index in erc721 == vaultIndex
    assertEq(IVault(vault).owner(), factoryContr.ownerOf(0));

    //Make sure vault itself is owned by sender
    assertEq(IVault(vault).owner(), sender);

    //Make sure erc721 is owned by sender
    assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

    //Transfer vault to another address
    factoryContr.safeTransferFrom(sender, receiver, factoryContr.vaultIndex(vault));

    //Make sure vault itself is owned by receiver
    assertEq(IVault(vault).owner(), receiver);

    //Make sure erc721 is owned by receiver
    assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), receiver);
    vm.stopPrank();  

  }
  //TODO: Odd test behavior
  function testFailTransferVaultNotOwner(address sender, address receiver) public {
    vm.assume(sender != address(0));
    vm.assume(receiver != address(0));
    vm.assume(receiver != address(1));


    vm.prank(sender);
    address vault = factoryContr.createVault(0);

    //Make sure index in erc721 == vaultIndex
    assertEq(IVault(vault).owner(), factoryContr.ownerOf(0));

    //Make sure vault itself is owned by sender
    assertEq(IVault(vault).owner(), sender);

    //Make sure erc721 is owned by sender
    assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

    //Transfer vault to another address by not owner
    vm.startPrank(receiver);
    vm.expectRevert("NOT_AUHTORIZED");
    factoryContr.safeTransferFrom(sender, receiver, factoryContr.vaultIndex(vault));
    vm.stopPrank();
    //Make sure vault itself is still owned by sender
    assertEq(IVault(vault).owner(), sender);

    //Make sure erc721 is still owned by sender
    assertEq(factoryContr.ownerOf(factoryContr.vaultIndex(vault)), sender);

  }

    function onERC721Received(address, address, uint256, bytes calldata ) public pure returns (bytes4) {
    return this.onERC721Received.selector;
  }

  function onERC1155Received(address, address, uint256, uint256, bytes calldata) public pure returns (bytes4) {
    return this.onERC1155Received.selector;
  }

}
