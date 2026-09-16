/*
 * Discharges the `percentMulDown` summary used by the RiskSteward specs.
 *
 * ProtocolEffects.spec replaces `PercentageMath.percentMulDown` with
 * `percentMulDownCVL` to keep nonlinear 256-bit arithmetic away from the solver. That
 * summary is only as good as the model, so these two rules prove the model against the
 * real assembly on `PercentageMathWrapper`, the wrapper aave-v4 already ships.
 *
 */

import "common/PercentMath.spec";

methods {
    function percentMulDown(uint256 value, uint256 percentage) external returns (uint256) envfree;
}

/*
 * The assembly guard is `value <= not(0) / percentage` (skipped when percentage is 0),
 * which is exactly `value * percentage <= type(uint256).max`. Proving the boundary
 * rather than assuming it is what makes the summary's one gap explicit: the model is
 * total, so on the reverting side it is strictly more permissive than the code.
 */
rule percentMulDownRevertsOnlyOnOverflow(uint256 value, uint256 percentage) {
    // Execute percentMulDown
    percentMulDown@withrevert(value, percentage);

    // Assert it reverts exactly when the intermediate product overflows 256 bits
    assert lastReverted <=> to_mathint(value) * to_mathint(percentage) > max_uint256;
}

// Wherever the Solidity produces a result, the model produces the same one --- which
// also pins the rounding direction, since `div` truncates and so does mathint division.
rule percentMulDownMatchesCVL(uint256 value, uint256 percentage) {
    // Execute percentMulDown
    uint256 solidityResult = percentMulDown(value, percentage);

    // Assert that the CVL model matches the assembly on the non-reverting domain
    assert solidityResult == percentMulDownCVL(value, percentage);
}
