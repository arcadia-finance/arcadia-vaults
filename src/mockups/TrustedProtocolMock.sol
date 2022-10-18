/**
 * Created by Arcadia Finance
 * https://www.arcadia.finance
 *
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity >=0.4.22 <0.9.0;

import '../interfaces/ITrustedProtocol.sol';
import './ERC4626SolmateMock.sol';


contract TrustedProtocolMock is MockERC4626 {
    constructor(ERC20 _underlying, string memory _name, string memory _symbol) MockERC4626(_underlying, _name, _symbol) {}
    
    function getOpenPosition(address vault) external view returns (uint128 openPosition) {
        openPosition = uint128(maxWithdraw(vault));
    }
}
