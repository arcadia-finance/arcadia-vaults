// This is a private, unpublished repository.
// All rights reserved to Arcadia Finance.
// Any modification, publication, reproduction, commercialisation, incorporation, sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.4.22 <0.9.0;

import "./../Liquidator.sol";

contract LiquidatorPaperTrading is Liquidator {
    constructor(address _factory, address _registry)
        Liquidator(_factory, _registry)
    {}

    function startAuction(
        address vaultAddress,
        uint256 life,
        address liquidationKeeper,
        address originalOwner,
        uint128 openDebt,
        uint8 liqThres,
        uint8 numeraire
    ) public override elevated returns (bool success) {
        require(
            auctionInfo[vaultAddress][life].startBlock == 0,
            "Liquidation already ongoing"
        );

        auctionInfo[vaultAddress][life].startBlock = uint128(block.number);
        auctionInfo[vaultAddress][life].liquidationKeeper = liquidationKeeper;
        auctionInfo[vaultAddress][life].originalOwner = originalOwner;
        auctionInfo[vaultAddress][life].openDebt = openDebt;
        auctionInfo[vaultAddress][life].liqThres = liqThres;
        auctionInfo[vaultAddress][life].numeraire = numeraire;

        //In the paper trading competition vaults are not auctioned
        auctionInfo[vaultAddress][life].stopped = true;

        return true;
    }
}
