// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {DirectionalRiskSteward} from 'src/DirectionalRiskSteward.sol';

// Exposes the one validation step every governed field goes through, so the
// direction rules can drive it with arbitrary inputs.
contract DirectionalRiskStewardHarness is DirectionalRiskSteward {
  constructor(
    address riskCouncil_,
    address initialOwner_
  ) DirectionalRiskSteward(riskCouncil_, initialOwner_) {}

  function validateParamUpdate(ParamUpdateValidationInput memory input) external view {
    _validateParamUpdate(input);
  }
}
