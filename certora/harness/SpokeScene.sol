// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {SpokeInstance} from 'aave-v4/spoke/instances/SpokeInstance.sol';
import {SpokeConfigurator} from 'aave-v4/spoke/SpokeConfigurator.sol';

/*
 * Scene contracts for spokeImmutability.spec.
 *
 * Pass-through wrappers over the real aave-v4 code; see the note in
 * HubScene.sol for why the indirection is needed.
 */

contract SpokeHarness is SpokeInstance {
  constructor(
    address oracle_,
    uint16 maxUserReservesLimit_
  ) SpokeInstance(oracle_, maxUserReservesLimit_) {}
}

contract SpokeConfiguratorHarness is SpokeConfigurator {
  constructor(address authority_) SpokeConfigurator(authority_) {}
}
