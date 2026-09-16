/*
 * RiskSteward — Oracle Properties.
 *
 * Properties:
 *  - a successful LST, stable, or Pendle update stamps that oracle's debounce to
 *    now and leaves every other oracle untouched;
 *  - the value it writes to an adapter is within the configured maxPercentChange
 *    of the value it read from that same adapter.
 */

import "common/PercentMath.spec";

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;
    function getOracleDebounce(address oracle) external returns (uint40) envfree;

    // The governed field of each adapter is a plain store/load pair, so a ghost
    // keyed by `calledContract` is a faithful model of it:
    //   LST     `_setCapParameters` writes `_maxYearlyRatioGrowthPercent`, which
    //           `getMaxYearlyGrowthRatePercent` returns   (PriceCapAdapterBase)
    //   stable  `setPriceCap` / `getPriceCap` on `_priceCap` (PriceCapAdapterStable)
    //   pendle  `setDiscountRatePerYear` / public `discountRatePerYear`
    // The model drops each adapter's own ACL and its extra input validation. Those
    // only ever reject writes the ghost accepts, so the magnitude rules below run
    // over a superset of the real paths.
    function _.getMaxYearlyGrowthRatePercent() external => lstGrowthOf(calledContract) expect uint256;
    function _.setCapParameters(IPriceCapAdapter.PriceCapUpdateParams params) external
        => storeLstGrowth(calledContract, params) expect void;

    function _.getPriceCap() external => priceCapOf(calledContract) expect int256;
    function _.setPriceCap(int256 cap) external => storePriceCap(calledContract, cap) expect void;

    function _.discountRatePerYear() external => discountOf(calledContract) expect uint64;
    function _.setDiscountRatePerYear(uint64 rate) external => storeDiscount(calledContract, rate) expect void;

    // Not governed by a magnitude bound: the snapshot ratio is range-checked in
    // RevertConditions.spec, and `isCapped` only gates the LST write.
    function _.getRatio() external => NONDET;
    function _.isCapped() external => NONDET;

    // The only nonlinear step in `_updateWithinAllowedRange`; LST and stable bounds
    // are relative so they reach it. Equivalence proven in PercentMulDownEquivalence.spec.
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal returns (uint256)
        => percentMulDownCVL(value, percentage);
}

// Persistent: unresolved adapter calls on these paths havoc, and the rules read the
// mirrored value back after the call.
persistent ghost mapping(address => uint256) adapterGrowthPct;
persistent ghost mapping(address => int256)  adapterPriceCap;
persistent ghost mapping(address => uint64)  adapterDiscount;

function lstGrowthOf(address adapter) returns uint256 {
    return adapterGrowthPct[adapter];
}

function storeLstGrowth(address adapter, IPriceCapAdapter.PriceCapUpdateParams params) {
    adapterGrowthPct[adapter] = assert_uint256(params.maxYearlyRatioGrowthPercent);
}

function priceCapOf(address adapter) returns int256 {
    return adapterPriceCap[adapter];
}

function storePriceCap(address adapter, int256 cap) {
    adapterPriceCap[adapter] = cap;
}

function discountOf(address adapter) returns uint64 {
    return adapterDiscount[adapter];
}

function storeDiscount(address adapter, uint64 rate) {
    adapterDiscount[adapter] = rate;
}

// The bound `_updateWithinAllowedRange` enforces, in mathint so callers need no casts.
function allowedDiff(bool isRelative, mathint maxPercentChange, mathint from) returns mathint {
    return isRelative ? (from * maxPercentChange) / 10000 : maxPercentChange;
}

function absDiff(mathint a, mathint b) returns mathint {
    return a > b ? a - b : b - a;
}

// ---------------------------------------------------------------------------
// Debounce stamping — the submitted oracle is stamped, every other one is not
// ---------------------------------------------------------------------------

rule lstPriceCapDebounceStamping(env e, address otherOracle) {
    // Create a valid PriceCapLstUpdate batch; index 0 is the element under test
    IRiskSteward.PriceCapLstUpdate[] updates;

    // No element of the batch names the snapshotted oracle
    require forall uint256 j. j < updates.length => updates[j].oracle != otherOracle;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updateLstPriceCaps(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(updates[0].oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}

rule stablePriceCapDebounceStamping(env e, address otherOracle) 
{
    // Create a valid PriceCapStableUpdate batch; index 0 is the element under test
    IRiskSteward.PriceCapStableUpdate[] updates;

    // No element of the batch names the snapshotted oracle
    require forall uint256 j. j < updates.length => updates[j].oracle != otherOracle;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updateStablePriceCaps(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(updates[0].oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}

rule pendleDiscountDebounceStamping(env e, address otherOracle) 
{
    // Create a valid DiscountRatePendleUpdate batch; index 0 is the element under test
    IRiskSteward.DiscountRatePendleUpdate[] updates;

    // No element of the batch names the snapshotted oracle
    require forall uint256 j. j < updates.length => updates[j].oracle != otherOracle;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updatePendleDiscountRates(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(updates[0].oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}

// ---------------------------------------------------------------------------
// Magnitude — the written value is within maxPercentChange of the value read
// ---------------------------------------------------------------------------

rule lstPriceCapMagnitude(env e, address oracle) {
    // Fetch the configured bound and the adapter's growth cap before the update
    bool isRelative = getConfig().oracle.priceCapLst.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().oracle.priceCapLst.maxPercentChange);
    mathint from = to_mathint(adapterGrowthPct[oracle]);

    // Create a valid PriceCapLstUpdate batch
    IRiskSteward.PriceCapLstUpdate[] updates;

    // Execute the update
    updateLstPriceCaps(e, updates);

    // Fetch the adapter's growth cap after the update
    mathint post = to_mathint(adapterGrowthPct[oracle]);

    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule stablePriceCapMagnitude(env e, address oracle) {
    // The steward only ever writes `toInt256` of a uint256 and the adapter rejects a
    // non-positive cap, so a negative stored cap is not a reachable pre-state.
    require adapterPriceCap[oracle] >= 0;

    // Fetch the configured bound and the adapter's price cap before the update
    bool isRelative = getConfig().oracle.priceCapStable.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().oracle.priceCapStable.maxPercentChange);
    mathint from = to_mathint(adapterPriceCap[oracle]);

    // Create a valid PriceCapStableUpdate batch
    IRiskSteward.PriceCapStableUpdate[] updates;

    // Execute the update
    updateStablePriceCaps(e, updates);

    // Fetch the adapter's price cap after the update
    mathint post = to_mathint(adapterPriceCap[oracle]);

    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule pendleDiscountRateMagnitude(env e, address oracle) {
    // Fetch the configured bound and the adapter's discount rate before the update
    bool isRelative = getConfig().oracle.discountRatePendle.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().oracle.discountRatePendle.maxPercentChange);
    mathint from = to_mathint(adapterDiscount[oracle]);

    // Create a valid DiscountRatePendleUpdate batch
    IRiskSteward.DiscountRatePendleUpdate[] updates;

    // Execute the update
    updatePendleDiscountRates(e, updates);

    // Fetch the adapter's discount rate after the update
    mathint post = to_mathint(adapterDiscount[oracle]);

    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}
