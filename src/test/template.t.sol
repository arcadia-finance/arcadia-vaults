// SPDX-License-Identifier: UNLICENSED
pragma solidity >0.8.10;

import "../../lib/forge-std/src/Test.sol";

import "../templateContract.sol";

contract templateContractTest is Test {
    using stdStorage for StdStorage;

    templateContract private templateContr;

    //this is a before
    constructor() {}

    //this is a before each
    function setUp() public {
        templateContr = new templateContract(address(this), 0);
    }

    // function testExample() public {
    //   assertTrue(true);
    // }

    // function testFailInputTooLarge() public {
    //   uint256 slot = stdstore.target(address(templateContr)).sig("exampleNumber()").find();
    //   bytes32 loc = bytes32(slot);
    //   bytes32 mockedCurrentTokenId = bytes32(abi.encode(10000));
    //   vm.store(address(templateContr), loc, mockedCurrentTokenId);
    //   templateContr.testInput();
    // }

    // function testInputStorage(uint256 input) public {
    //   templateContr.storeInput(input);
    // }
}
