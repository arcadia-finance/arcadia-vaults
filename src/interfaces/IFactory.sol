/** 
    This is a private, unpublished repository.
    All rights reserved to Arcadia Finance.
    Any modification, publication, reproduction, commercialisation, incorporation, 
    sharing or any other kind of use of any part of this code or derivatives thereof is not allowed.
    
    SPDX-License-Identifier: UNLICENSED
 */
pragma solidity >=0.4.22 <0.9.0;

interface IFactory {
    function isVault(address vaultAddress) external view returns (bool);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id
    ) external;

    function liquidate(address vault) external returns (bool);

    function vaultIndex(address vaultAddress) external view returns (uint256);

    function getCurrentRegistry() external view returns (address);

    function addNumeraire(uint256 numeraire, address stable) external;

    function numeraireCounter() external view returns (uint256);

    function numeraireToStable(uint256) external view returns (address);
}
