/*
 * RiskSteward — Oracle Properties.
 *
 * Property: a successful LST, stable, or Pendle update stamps that oracle's
 * debounce to now and leaves every other oracle untouched.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getOracleDebounce(address oracle) external returns (uint40) envfree;

    // Adapter reads used by oracle validation.
    function _.getMaxYearlyGrowthRatePercent() external => NONDET;
    function _.getRatio() external => NONDET;
    function _.getPriceCap() external => NONDET;
    function _.discountRatePerYear() external => NONDET;
    function _.isCapped() external => NONDET;

    // Adapter writes are irrelevant to steward-owned debounce storage.
    function _.setCapParameters(IPriceCapAdapter.PriceCapUpdateParams) external => NONDET;
    function _.setPriceCap(int256) external => NONDET;
    function _.setDiscountRatePerYear(uint64) external => NONDET;
}

rule lstPriceCapDebounceStamping(env e, IRiskSteward.PriceCapLstUpdate u, address otherOracle) {
    require otherOracle != u.oracle,"Other oracle must be different from the input";

    // Create a valid PriceCapLstUpdate array and constrain it to the input
    IRiskSteward.PriceCapLstUpdate[] updates;
    require updates.length == 1
        && updates[0].oracle == u.oracle
        && updates[0].priceCapUpdateParams.snapshotRatio == u.priceCapUpdateParams.snapshotRatio
        && updates[0].priceCapUpdateParams.snapshotTimestamp == u.priceCapUpdateParams.snapshotTimestamp
        && updates[0].priceCapUpdateParams.maxYearlyRatioGrowthPercent == u.priceCapUpdateParams.maxYearlyRatioGrowthPercent;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updateLstPriceCaps(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(u.oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}

rule stablePriceCapDebounceStamping(env e,IRiskSteward.PriceCapStableUpdate u,address otherOracle) 
{
    require otherOracle != u.oracle,"Other oracle must be different from the input";

    // Create a valid PriceCapStableUpdate array and constrain it to the input
    IRiskSteward.PriceCapStableUpdate[] updates;
    require updates.length == 1
        && updates[0].oracle == u.oracle
        && updates[0].priceCap == u.priceCap;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updateStablePriceCaps(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(u.oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}

rule pendleDiscountDebounceStamping(env e,IRiskSteward.DiscountRatePendleUpdate u,address otherOracle) 
{
    require otherOracle != u.oracle,"Other oracle must be different from the input";

    // Create a valid DiscountRatePendleUpdate array and constrain it to the input
    IRiskSteward.DiscountRatePendleUpdate[] updates;
    require updates.length == 1
        && updates[0].oracle == u.oracle
        && updates[0].discountRate == u.discountRate;

    // Fetch the oracle debounce of other oracle before the update
    uint40 otherBefore = getOracleDebounce(otherOracle);

    // Execute the update
    updatePendleDiscountRates(e, updates);

    // Assert that the submitted oracle stamps to tx time and the other oracle is untouched
    assert to_mathint(getOracleDebounce(u.oracle)) == to_mathint(e.block.timestamp);
    assert getOracleDebounce(otherOracle) == otherBefore;
}
