/*
 * RiskSteward — Revert Conditions.
 *
 * Property: a council call reverts if it names an out-of-scope field, a mismatched
 * configurator, a zero write.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;

    // `_validateLstPriceCaps` compares snapshotRatio against the adapter's live ratio.
    // Left unresolved that read is a fresh NONDET per call site, so the comparison is
    // unobservable from the spec.
    function _.getRatio() external => ratioOf(calledContract) expect int256;

    // `_executeLstPriceCaps` re-reads the adapter after installing the new cap params and
    // rejects the update if the cap is already binding. 
    function _.isCapped() external => cappedOf(calledContract) expect bool;
}

// Persistent: unresolved adapter writes on this path havoc, and the rule reads the
// ratio after the call.
persistent ghost mapping(address => int256) adapterRatio;

// Get the ratio of the adapter
function ratioOf(address adapter) returns int256 {
    return adapterRatio[adapter];
}

// Cap flag is read after `setCapParameters`.
persistent ghost mapping(address => bool) adapterCapped;

// Get the capped flag of the adapter
function cappedOf(address adapter) returns bool {
    return adapterCapped[adapter];
}

// EngineFlags.KEEP_CURRENT = type(uint256).max - 652.
definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;

// EngineFlags.KEEP_CURRENT_ADDRESS = address(type(uint160).max).
definition KEEP_CURRENT_ADDRESS() returns address = 0xffffffffffffffffffffffffffffffffffffffff;

// ---------------------------------------------------------------------------
// Helpers: pinned configurator addresses.
// ---------------------------------------------------------------------------

function pinnedHubConfigurator() returns address {
    IRiskSteward.Config cfg = getConfig();
    return cfg.hub.configurator;
}

function pinnedSpokeConfigurator() returns address {
    IRiskSteward.Config cfg = getConfig();
    return cfg.spoke.configurator;
}

// ---------------------------------------------------------------------------
// updateHubAssetIRs 
// ---------------------------------------------------------------------------

definition irElementInScope(IAaveV4ConfigEngine.AssetConfigUpdate u) returns bool =
    u.liquidityFee == KEEP_CURRENT() &&
    u.feeReceiver == KEEP_CURRENT_ADDRESS() &&
    u.irStrategy == KEEP_CURRENT_ADDRESS() &&
    u.reinvestmentController == KEEP_CURRENT_ADDRESS();

// Verify that the updateHubAssetIRs function reverts if an element is not in scope
rule hubIrSuccessImpliesInScope(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => irElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// Hub-side: updateHubAssetIRs
// ---------------------------------------------------------------------------

// Verify that the updateHubAssetIRs function reverts if the hubConfigurator does not match the pinned configurator
rule hubIrSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that success implies every hubConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].hubConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// updateHubSpokeCaps 
// ---------------------------------------------------------------------------

definition capsElementInScope(IAaveV4ConfigEngine.SpokeConfigUpdate u) returns bool =
    u.riskPremiumThreshold == KEEP_CURRENT() &&
    u.active == KEEP_CURRENT() &&
    u.halted == KEEP_CURRENT();

// Verify that the updateHubSpokeCaps function reverts if an element is not in scope
rule hubCapsSuccessImpliesInScope(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => capsElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// Hub-side: updateHubSpokeCaps
// ---------------------------------------------------------------------------

// Verify that the updateHubSpokeCaps function reverts if the hubConfigurator does not match the pinned configurator
rule hubCapsSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that success implies every hubConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].hubConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// updateReserveConfigs 
// ---------------------------------------------------------------------------

definition reserveElementInScope(IAaveV4ConfigEngine.ReserveConfigUpdate u) returns bool =
    u.priceSource == KEEP_CURRENT_ADDRESS() &&
    u.paused == KEEP_CURRENT() &&
    u.frozen == KEEP_CURRENT() &&
    u.borrowable == KEEP_CURRENT() &&
    u.receiveSharesEnabled == KEEP_CURRENT();

// Verify that the updateReserveConfigs function reverts if an element is not in scope
rule reserveSuccessImpliesInScope(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => reserveElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs 
// ---------------------------------------------------------------------------

// Verify that the updateDynamicReserveConfigs function reverts if the liquidationFee is not KEEP_CURRENT
rule dynUpdateSuccessImpliesFeeKept(env e,IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) 
{

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Assert that success implies every liquidationFee is KEEP_CURRENT
    assert forall uint256 i. i < updates.length => updates[i].liquidationFee == KEEP_CURRENT();
}

// ---------------------------------------------------------------------------
// Spoke-side: updateDynamicReserveConfigs
// ---------------------------------------------------------------------------

// Verify that the updateDynamicReserveConfigs function reverts if the spokeConfigurator does not match the pinned configurator
rule dynUpdateSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Assert that success implies every spokeConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].spokeConfigurator == pinned;
}


// ---------------------------------------------------------------------------
// Spoke-side: updateReserveConfigs
// ---------------------------------------------------------------------------

// Verify that the updateReserveConfigs function reverts if the spokeConfigurator does not match the pinned configurator
rule reserveSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that success implies every spokeConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].spokeConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// Spoke-side: addDynamicReserveConfigs
// ---------------------------------------------------------------------------

// Verify that the addDynamicReserveConfigs function reverts if the spokeConfigurator does not match the pinned configurator
rule dynAddSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    addDynamicReserveConfigs(e, additions);

    // Assert that success implies every spokeConfigurator matches the pinned configurator
    assert forall uint256 i. i < additions.length => additions[i].spokeConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// Spoke-side: updateSpokeLiquidationConfigs
// ---------------------------------------------------------------------------

// Verify that the updateSpokeLiquidationConfigs function reverts if the spokeConfigurator does not match the pinned configurator
rule liqSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that success implies every spokeConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].spokeConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// Zero-value rejection 
// ---------------------------------------------------------------------------

// A governed param may be left alone via KEEP_CURRENT, but never actively set to
// zero because allowing it would silently disable a risk limit rather than tighten it.
// Where no sentinel exists (dynamic additions and the three oracle families) any zero is rejected.
// updateDynamicReserveConfigs. sentinel-guarded.
definition dynUpdateZeroViolation(IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) returns bool =
    (u.collateralFactor != KEEP_CURRENT() && u.collateralFactor == 0) ||
    (u.maxLiquidationBonus != KEEP_CURRENT() && u.maxLiquidationBonus == 0);

// Verify that the updateDynamicReserveConfigs function reverts if a zero write to a governed field causes a revert
rule dynUpdateZeroReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) {

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && dynUpdateZeroViolation(updates[i])) => lastReverted;
}

// addDynamicReserveConfigs
definition dynAddZeroViolation(IAaveV4ConfigEngine.DynamicReserveConfigAddition a) returns bool =
    a.dynamicConfig.collateralFactor == 0 || a.dynamicConfig.maxLiquidationBonus == 0;

// Verify that the addDynamicReserveConfigs function reverts if a zero write to a governed field causes a revert
rule dynAddZeroReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions) {

    // Execute the update
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < additions.length && dynAddZeroViolation(additions[i])) => lastReverted;
}

// updateSpokeLiquidationConfigs
definition liqZeroViolation(IAaveV4ConfigEngine.LiquidationConfigUpdate u) returns bool =
    (u.targetHealthFactor != KEEP_CURRENT() && u.targetHealthFactor == 0) ||
    (u.healthFactorForMaxBonus != KEEP_CURRENT() && u.healthFactorForMaxBonus == 0) ||
    (u.liquidationBonusFactor != KEEP_CURRENT() && u.liquidationBonusFactor == 0);

// Verify that the updateSpokeLiquidationConfigs function reverts if a zero write to a governed field causes a revert
rule liqZeroReverts(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {

    // Execute the update
    updateSpokeLiquidationConfigs@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && liqZeroViolation(updates[i])) => lastReverted;
}

// updateLstPriceCaps. 
definition lstZeroViolation(IRiskSteward.PriceCapLstUpdate u) returns bool =
    u.priceCapUpdateParams.snapshotRatio == 0 ||
    u.priceCapUpdateParams.snapshotTimestamp == 0 ||
    u.priceCapUpdateParams.maxYearlyRatioGrowthPercent == 0;

// Verify that the updateLstPriceCaps function reverts if a zero write to a governed field causes a revert
rule lstZeroReverts(env e, IRiskSteward.PriceCapLstUpdate[] updates) {

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && lstZeroViolation(updates[i])) => lastReverted;
}

// Verify that the updateStablePriceCaps function reverts if a zero write to a governed field causes a revert
rule stableZeroReverts(env e, IRiskSteward.PriceCapStableUpdate[] updates) {

    // Execute the update
    updateStablePriceCaps@withrevert(e, updates);

    // Assert that a zero priceCap causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].priceCap == 0) => lastReverted;
}

// Verify that the updatePendleDiscountRates function reverts if a zero write to a governed field causes a revert
rule pendleZeroReverts(env e, IRiskSteward.DiscountRatePendleUpdate[] updates) {

    // Execute the update
    updatePendleDiscountRates@withrevert(e, updates);

    // Assert that a zero discountRate causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].discountRate == 0) => lastReverted;
}

// ===========================================================================
// Oracle-path gates with no other coverage
// ===========================================================================

// Verify that the updateLstPriceCaps function reverts if the snapshot ratio is forward-looking
rule lstSnapshotMustBeBackwardLooking(env e, IRiskSteward.PriceCapLstUpdate[] updates) {

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that a forward-looking snapshot causes a revert
    assert (exists uint256 i. i < updates.length
        && to_mathint(updates[i].priceCapUpdateParams.snapshotRatio) > to_mathint(adapterRatio[updates[i].oracle]))
        => lastReverted;
}

// Verify that the updateLstPriceCaps function reverts if the adapter is left in a capped state
rule lstCappedResultReverts(env e, IRiskSteward.PriceCapLstUpdate[] updates) {

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that an adapter left in a capped state causes a revert
    assert (exists uint256 i. i < updates.length && adapterCapped[updates[i].oracle]) => lastReverted;
}

// Verify that the updateStablePriceCaps function reverts if the priceCap is KEEP_CURRENT
rule stableRejectsKeepCurrent(env e, IRiskSteward.PriceCapStableUpdate[] updates) {

    // Execute the update
    updateStablePriceCaps@withrevert(e, updates);

    // Assert that the bypassed sentinel still cannot be written
    assert (exists uint256 i. i < updates.length && updates[i].priceCap == KEEP_CURRENT())
        => lastReverted;
}

// Verify that the updatePendleDiscountRates function reverts if the discountRate is KEEP_CURRENT
rule pendleRejectsKeepCurrent(env e, IRiskSteward.DiscountRatePendleUpdate[] updates) {

    // Execute the update
    updatePendleDiscountRates@withrevert(e, updates);

    // Assert that the bypassed sentinel still cannot be written
    assert (exists uint256 i. i < updates.length && updates[i].discountRate == KEEP_CURRENT())
        => lastReverted;
}