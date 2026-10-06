/*
 * DirectionalRiskSteward — Update direction.
 *
 * Property: a param restricted to REDUCE never goes up, one restricted to INCREASE
 * never goes down, and the direction check adds that single revert reason on top of
 * the existing debounce and range checks, nothing more.
 *
 * Every governed field reaches `_validateParamUpdate`, which the harness exposes. The
 * call sites are textually the same as RiskSteward's, so how they wire `currentValue`
 * and `riskConfig` is covered by the RiskSteward suite, not here.
 */

import "common/PercentMath.spec";

methods {
    // Same summary as ProtocolEffects.spec, proven in PercentMulDownEquivalence.spec.
    // Both calls in `directionOnlyAddsItsOwnCheck` see the same model, so the gap
    // where the Solidity reverts and the model does not cancels out.
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal returns (uint256)
        => percentMulDownCVL(value, percentage);
}

// EngineFlags.KEEP_CURRENT = type(uint256).max - 652.
definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;

// Make sure a REDUCE param never goes up
rule reduceNeverIncreases(env e, IDirectionalRiskSteward.ParamUpdateValidationInput input) {
    require input.riskConfig.direction == IDirectionalRiskSteward.Direction.REDUCE;

    validateParamUpdate(e, input);

    assert input.newValue != KEEP_CURRENT() => input.newValue <= input.currentValue;
}

// Make sure an INCREASE param never goes down
rule increaseNeverDecreases(env e, IDirectionalRiskSteward.ParamUpdateValidationInput input) {
    require input.riskConfig.direction == IDirectionalRiskSteward.Direction.INCREASE;

    validateParamUpdate(e, input);

    assert input.newValue != KEEP_CURRENT() => input.newValue >= input.currentValue;
}

// Make sure the direction only adds the wrong-way revert: against the same input
// with direction BOTH, it reverts exactly when BOTH reverts or the move goes the
// wrong way. This also shows the sentinel is never blocked by its direction.
rule directionOnlyAddsItsOwnCheck(
    env e,
    IDirectionalRiskSteward.ParamUpdateValidationInput input,
    IDirectionalRiskSteward.ParamUpdateValidationInput both
) {
    require both.currentValue == input.currentValue
        && both.newValue == input.newValue
        && both.lastUpdated == input.lastUpdated
        && both.riskConfig.minDelay == input.riskConfig.minDelay
        && both.riskConfig.maxPercentChange == input.riskConfig.maxPercentChange
        && both.riskConfig.isChangeRelative == input.riskConfig.isChangeRelative
        && both.riskConfig.direction == IDirectionalRiskSteward.Direction.BOTH;

    validateParamUpdate@withrevert(e, input);
    bool reverted = lastReverted;

    validateParamUpdate@withrevert(e, both);
    bool bothReverted = lastReverted;

    bool wrongWay = input.newValue != KEEP_CURRENT() && (
        (input.riskConfig.direction == IDirectionalRiskSteward.Direction.REDUCE && input.newValue > input.currentValue)
        || (input.riskConfig.direction == IDirectionalRiskSteward.Direction.INCREASE && input.newValue < input.currentValue)
    );

    assert reverted <=> (bothReverted || wrongWay);
}
