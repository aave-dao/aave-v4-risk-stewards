// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4Base, AaveV4BaseGetters} from 'aave-address-book/AaveV4Base.sol';
import {
  ISpoke,
  IHub,
  ITokenizationSpoke,
  ISpokeConfigurator,
  PositionManagers
} from 'aave-address-book/AaveV4.sol';

import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

/// @title RiskStewardsBaseChain
/// @author Aave Labs
/// @notice Base-scoped base for concrete RiskSteward payloads. Wires the deployed steward
/// address plus the full hub/spoke/tokenization-spoke arrays from the address book into the
/// generic `RiskStewardsBase`. Named `…BaseChain` because `RiskStewardsBase` is the
/// chain-agnostic base it extends.
abstract contract RiskStewardsBaseChain is RiskStewardsBase {
  constructor() RiskStewardsBase(AaveV4Base.RISK_STEWARD) {}

  function _getHubs() internal pure override returns (IHub[] memory) {
    return AaveV4BaseGetters.getAllHubs();
  }

  function _getSpokes() internal pure override returns (ISpoke[] memory) {
    return AaveV4BaseGetters.getAllSpokes();
  }

  function _getTokenizationSpokes() internal pure override returns (ITokenizationSpoke[] memory) {
    return AaveV4BaseGetters.getAllTokenizationSpokes();
  }

  function _getPositionManagers() internal pure override returns (PositionManagers memory) {
    return AaveV4BaseGetters.getPositionManagers();
  }

  function _accessManager() internal pure override returns (address) {
    return address(AaveV4Base.ACCESS_MANAGER);
  }

  function _spokeConfigurator() internal pure override returns (ISpokeConfigurator) {
    return AaveV4Base.SPOKE_CONFIGURATOR;
  }
}
