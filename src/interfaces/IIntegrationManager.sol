pragma solidity >=0.8.0 <0.9.0;

/// @title IIntegrationManager interface
/// @notice Interface for the IntegrationManager
interface IIntegrationManager {
        function receiveCallFromVault(
        address _caller,
        bytes calldata _callArgs
        ) external;
}