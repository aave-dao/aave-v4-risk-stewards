// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4EthereumGetters} from 'aave-address-book/AaveV4Ethereum.sol';

import {RiskStewardsBase} from '../RiskStewardsBase.s.sol';

/// @title RiskStewardsEthereum
/// @author Aave Labs
/// @notice Ethereum-scoped base for concrete RiskSteward payloads. Wires the deployed steward
/// address plus the full hub/spoke/tokenization-spoke arrays from the address book into the
/// generic `RiskStewardsBase`.
abstract contract RiskStewardsEthereum is RiskStewardsBase {
  // TODO: replace with the deployed Ethereum RiskSteward address once v4 ships.
  address internal constant ETHEREUM_RISK_STEWARD = address(0);

  constructor()
    RiskStewardsBase(
      ETHEREUM_RISK_STEWARD,
      AaveV4EthereumGetters.getAllSpokes(),
      AaveV4EthereumGetters.getAllHubs(),
      AaveV4EthereumGetters.getAllTokenizationSpokes()
    )
  {}
}
