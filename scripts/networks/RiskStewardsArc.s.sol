// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Arc, AaveV4ArcGetters} from 'aave-address-book/AaveV4Arc.sol';
import {
  ISpoke,
  IHub,
  ITokenizationSpoke,
  ISpokeConfigurator,
  PositionManagers
} from 'aave-address-book/AaveV4.sol';

import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

/// @title RiskStewardsArc
/// @author Aave Labs
/// @notice Arc-scoped base for concrete RiskSteward payloads. Wires the deployed steward
/// address plus the full hub/spoke/tokenization-spoke arrays from the address book into the
/// generic `RiskStewardsBase`.
/// @dev safe-utils registers no MultiSend deployment for Arc (5042), so `run` reverts when
/// called with `broadcastToSafe: true`. Run with it set to false and hand the printed calldata
/// to the council Safe.
abstract contract RiskStewardsArc is RiskStewardsBase {
  constructor() RiskStewardsBase(AaveV4Arc.RISK_STEWARD) {}

  function _getHubs() internal pure override returns (IHub[] memory) {
    return AaveV4ArcGetters.getAllHubs();
  }

  function _getSpokes() internal pure override returns (ISpoke[] memory) {
    return AaveV4ArcGetters.getAllSpokes();
  }

  function _getTokenizationSpokes() internal pure override returns (ITokenizationSpoke[] memory) {
    return AaveV4ArcGetters.getAllTokenizationSpokes();
  }

  function _getPositionManagers() internal pure override returns (PositionManagers memory) {
    return AaveV4ArcGetters.getPositionManagers();
  }

  function _accessManager() internal pure override returns (address) {
    return address(AaveV4Arc.ACCESS_MANAGER);
  }

  function _spokeConfigurator() internal pure override returns (ISpokeConfigurator) {
    return AaveV4Arc.SPOKE_CONFIGURATOR;
  }
}
