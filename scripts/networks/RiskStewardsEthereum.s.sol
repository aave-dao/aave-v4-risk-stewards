// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Ethereum, AaveV4EthereumGetters} from 'aave-address-book/AaveV4Ethereum.sol';
import {
  ISpoke,
  IHub,
  ITokenizationSpoke,
  ISpokeConfigurator,
  PositionManagers
} from 'aave-address-book/AaveV4.sol';

import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

/// @title RiskStewardsEthereum
/// @author Aave Labs
/// @notice Ethereum-scoped base for concrete RiskSteward payloads. Wires the deployed steward
/// address plus the full hub/spoke/tokenization-spoke arrays from the address book into the
/// generic `RiskStewardsBase`.
abstract contract RiskStewardsEthereum is RiskStewardsBase {
  constructor() RiskStewardsBase(AaveV4Ethereum.RISK_STEWARD) {}

  function _getHubs() internal pure override returns (IHub[] memory) {
    return AaveV4EthereumGetters.getAllHubs();
  }

  function _getSpokes() internal pure override returns (ISpoke[] memory) {
    return AaveV4EthereumGetters.getAllSpokes();
  }

  function _getTokenizationSpokes() internal pure override returns (ITokenizationSpoke[] memory) {
    return AaveV4EthereumGetters.getAllTokenizationSpokes();
  }

  function _getPositionManagers() internal pure override returns (PositionManagers memory) {
    return AaveV4EthereumGetters.getPositionManagers();
  }

  function _accessManager() internal pure override returns (address) {
    return address(AaveV4Ethereum.ACCESS_MANAGER);
  }

  function _spokeConfigurator() internal pure override returns (ISpokeConfigurator) {
    return AaveV4Ethereum.SPOKE_CONFIGURATOR;
  }
}
