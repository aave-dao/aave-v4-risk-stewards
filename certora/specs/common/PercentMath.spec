/*
 * CVL model of aave-v4 `PercentageMath.percentMulDown`, shared by every spec that
 * summarizes it.
 *
 * The Solidity is inline assembly performing a 256-bit `mul` then a `div`, guarded by
 * an overflow check (PercentageMath.sol:15-27). Nonlinear 256-bit arithmetic is the
 * dominant SMT cost on the RiskSteward write path, so specs replace the call with this
 * mathint equivalent, which the solver handles as unbounded integer arithmetic.
 *
 * Equivalence with the Solidity is proven in PercentMulDownEquivalence.spec, which also
 * pins the exact region where the Solidity reverts and this model does not.
 */

function percentMulDownCVL(uint256 value, uint256 percentage) returns uint256 {
    // floor(value * percentage / 1e4), mirroring `div(mul(value, percentage), 1e4)`.
    // The cast prunes products above ~1e4 * 2^256, which the Solidity rejects anyway.
    return require_uint256((to_mathint(value) * to_mathint(percentage)) / 10000);
}
