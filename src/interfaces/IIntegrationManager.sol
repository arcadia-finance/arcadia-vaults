pragma solidity >=0.8.0 <0.9.0;

/// @title IIntegrationManager interface
/// @notice Interface for the IntegrationManager
interface IIntegrationManager {
        function __callOnIntegration(
        address _caller,
        address _vaultProxy,
        bytes memory _callArgs
        ) external returns (bool);
}