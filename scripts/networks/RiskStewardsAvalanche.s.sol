// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Avalanche, AaveV4AvalancheGetters} from 'aave-address-book/AaveV4Avalanche.sol';
import {
  ISpoke,
  IHub,
  ITokenizationSpoke,
  ISpokeConfigurator,
  PositionManagers
} from 'aave-address-book/AaveV4.sol';

import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

/// @title RiskStewardsAvalanche
/// @author Aave Labs
/// @notice Avalanche-scoped base for concrete RiskSteward payloads. Wires the deployed steward
/// address plus the full hub/spoke/tokenization-spoke arrays from the address book into the
/// generic `RiskStewardsBase`.
abstract contract RiskStewardsAvalanche is RiskStewardsBase {
  // TODO: replace with the deployed Avalanche RiskSteward address once v4 ships.
  address internal constant AVALANCHE_RISK_STEWARD = address(0);

  constructor() RiskStewardsBase(AVALANCHE_RISK_STEWARD) {}

  function _getHubs() internal pure override returns (IHub[] memory) {
    return AaveV4AvalancheGetters.getAllHubs();
  }

  function _getSpokes() internal pure override returns (ISpoke[] memory) {
    return AaveV4AvalancheGetters.getAllSpokes();
  }

  function _getTokenizationSpokes() internal pure override returns (ITokenizationSpoke[] memory) {
    return AaveV4AvalancheGetters.getAllTokenizationSpokes();
  }

  function _getPositionManagers() internal pure override returns (PositionManagers memory) {
    return AaveV4AvalancheGetters.getPositionManagers();
  }

  function _accessManager() internal pure override returns (address) {
    return address(AaveV4Avalanche.ACCESS_MANAGER);
  }

  function _spokeConfigurator() internal pure override returns (ISpokeConfigurator) {
    return AaveV4Avalanche.SPOKE_CONFIGURATOR;
  }
}
