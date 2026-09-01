/*
 * RiskSteward — Revert Conditions.
 *
 * Property: a council call reverts if it names an out-of-scope field, a mismatched
 * configurator, a zero write, or an empty batch.
 */

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;
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
// updateHubAssetIRs — fee / strategy / reinvestment fields are out of scope
// ---------------------------------------------------------------------------

definition irElementInScope(IAaveV4ConfigEngine.AssetConfigUpdate u) returns bool =
    u.liquidityFee == KEEP_CURRENT() &&
    u.feeReceiver == KEEP_CURRENT_ADDRESS() &&
    u.irStrategy == KEEP_CURRENT_ADDRESS() &&
    u.reinvestmentController == KEEP_CURRENT_ADDRESS();

rule hubIrForbiddenFieldReverts(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {

    // Execute the update
    updateHubAssetIRs@withrevert(e, updates);

    // Assert that an out-of-scope field causes a revert
    assert (exists uint256 i. i < updates.length && !irElementInScope(updates[i])) => lastReverted;
}

rule hubIrSuccessImpliesInScope(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => irElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// Hub-side: updateHubAssetIRs
// ---------------------------------------------------------------------------

rule hubIrMismatchReverts(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubAssetIRs@withrevert(e, updates);

    // Assert that a mismatched hubConfigurator causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].hubConfigurator != pinned) => lastReverted;
}

rule hubIrSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that success implies every hubConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].hubConfigurator == pinned;
}


// ---------------------------------------------------------------------------
// updateHubSpokeCaps — risk premium threshold / active / halted out of scope
// ---------------------------------------------------------------------------

definition capsElementInScope(IAaveV4ConfigEngine.SpokeConfigUpdate u) returns bool =
    u.riskPremiumThreshold == KEEP_CURRENT() &&
    u.active == KEEP_CURRENT() &&
    u.halted == KEEP_CURRENT();

rule hubCapsForbiddenFieldReverts(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {

    // Execute the update
    updateHubSpokeCaps@withrevert(e, updates);

    // Assert that an out-of-scope field causes a revert
    assert (exists uint256 i. i < updates.length && !capsElementInScope(updates[i])) => lastReverted;
}

rule hubCapsSuccessImpliesInScope(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => capsElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// Hub-side: updateHubSpokeCaps
// ---------------------------------------------------------------------------

rule hubCapsMismatchReverts(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubSpokeCaps@withrevert(e, updates);

    // Assert that a mismatched hubConfigurator causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].hubConfigurator != pinned) => lastReverted;
}

rule hubCapsSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {
    // Fetch the pinned hub configurator
    address pinned = pinnedHubConfigurator();

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that success implies every hubConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].hubConfigurator == pinned;
}

// ---------------------------------------------------------------------------
// updateReserveConfigs — price source and the four reserve flags out of scope
// ---------------------------------------------------------------------------

definition reserveElementInScope(IAaveV4ConfigEngine.ReserveConfigUpdate u) returns bool =
    u.priceSource == KEEP_CURRENT_ADDRESS() &&
    u.paused == KEEP_CURRENT() &&
    u.frozen == KEEP_CURRENT() &&
    u.borrowable == KEEP_CURRENT() &&
    u.receiveSharesEnabled == KEEP_CURRENT();

rule reserveForbiddenFieldReverts(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {

    // Execute the update
    updateReserveConfigs@withrevert(e, updates);

    // Assert that an out-of-scope field causes a revert
    assert (exists uint256 i. i < updates.length && !reserveElementInScope(updates[i])) => lastReverted;
}

rule reserveSuccessImpliesInScope(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that success implies every element is in scope
    assert forall uint256 i. i < updates.length => reserveElementInScope(updates[i]);
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs — liquidationFee out of scope
// ---------------------------------------------------------------------------

rule dynUpdateLiquidationFeeReverts(env e,IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) 
{

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that a non-KEEP_CURRENT liquidationFee causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].liquidationFee != KEEP_CURRENT()) => lastReverted;
}

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

rule dynUpdateMismatchReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that a mismatched spokeConfigurator causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].spokeConfigurator != pinned) => lastReverted;
}

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

rule reserveMismatchReverts(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateReserveConfigs@withrevert(e, updates);

    // Assert that a mismatched spokeConfigurator causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].spokeConfigurator != pinned) => lastReverted;
}

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

rule dynAddMismatchReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that a mismatched spokeConfigurator causes a revert
    assert (exists uint256 i. i < additions.length && additions[i].spokeConfigurator != pinned) => lastReverted;
}

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

rule liqMismatchReverts(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateSpokeLiquidationConfigs@withrevert(e, updates);

    // Assert that a mismatched spokeConfigurator causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].spokeConfigurator != pinned) => lastReverted;
}

rule liqSuccessImpliesAllMatched(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {
    // Fetch the pinned spoke configurator
    address pinned = pinnedSpokeConfigurator();

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that success implies every spokeConfigurator matches the pinned configurator
    assert forall uint256 i. i < updates.length => updates[i].spokeConfigurator == pinned;
}

// ===========================================================================
// Zero-value rejection (InvalidUpdateToZero, 12 sites)
// ===========================================================================
//
// A governed param may be left alone via KEEP_CURRENT, but never actively set to
// zero because allowing it would silently disable a risk limit rather than tighten it.
// Where no sentinel exists (dynamic additions and the three oracle families) any zero is rejected.

// updateDynamicReserveConfigs. sentinel-guarded.
definition dynUpdateZeroViolation(IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) returns bool =
    (u.collateralFactor != KEEP_CURRENT() && u.collateralFactor == 0) ||
    (u.maxLiquidationBonus != KEEP_CURRENT() && u.maxLiquidationBonus == 0);

rule dynUpdateZeroReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) {

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && dynUpdateZeroViolation(updates[i])) => lastReverted;
}

// addDynamicReserveConfigs. No sentinel: an addition always writes both fields, 
// so zero is unconditionally invalid.
definition dynAddZeroViolation(IAaveV4ConfigEngine.DynamicReserveConfigAddition a) returns bool =
    a.dynamicConfig.collateralFactor == 0 || a.dynamicConfig.maxLiquidationBonus == 0;

rule dynAddZeroReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions) {

    // Execute the update
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < additions.length && dynAddZeroViolation(additions[i])) => lastReverted;
}

// updateSpokeLiquidationConfigs (RiskSteward.sol:510-524), sentinel-guarded.
definition liqZeroViolation(IAaveV4ConfigEngine.LiquidationConfigUpdate u) returns bool =
    (u.targetHealthFactor != KEEP_CURRENT() && u.targetHealthFactor == 0) ||
    (u.healthFactorForMaxBonus != KEEP_CURRENT() && u.healthFactorForMaxBonus == 0) ||
    (u.liquidationBonusFactor != KEEP_CURRENT() && u.liquidationBonusFactor == 0);

rule liqZeroReverts(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {

    // Execute the update
    updateSpokeLiquidationConfigs@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && liqZeroViolation(updates[i])) => lastReverted;
}

// updateLstPriceCaps (RiskSteward.sol:563-565). All three snapshot params are
// required; a zero snapshotTimestamp would make the growth window meaningless.
definition lstZeroViolation(IRiskSteward.PriceCapLstUpdate u) returns bool =
    u.priceCapUpdateParams.snapshotRatio == 0 ||
    u.priceCapUpdateParams.snapshotTimestamp == 0 ||
    u.priceCapUpdateParams.maxYearlyRatioGrowthPercent == 0;

rule lstZeroReverts(env e, IRiskSteward.PriceCapLstUpdate[] updates) {

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that a zero write to a governed field causes a revert
    assert (exists uint256 i. i < updates.length && lstZeroViolation(updates[i])) => lastReverted;
}

// updateStablePriceCaps (RiskSteward.sol:589).
rule stableZeroReverts(env e, IRiskSteward.PriceCapStableUpdate[] updates) {

    // Execute the update
    updateStablePriceCaps@withrevert(e, updates);

    // Assert that a zero priceCap causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].priceCap == 0) => lastReverted;
}

// updatePendleDiscountRates (RiskSteward.sol:608).
rule pendleZeroReverts(env e, IRiskSteward.DiscountRatePendleUpdate[] updates) {

    // Execute the update
    updatePendleDiscountRates@withrevert(e, updates);

    // Assert that a zero discountRate causes a revert
    assert (exists uint256 i. i < updates.length && updates[i].discountRate == 0) => lastReverted;
}

// ===========================================================================
// Empty batch rejection (NoZeroUpdates, 9 sites)
// ===========================================================================


rule emptyHubAssetIRsReverts(env e, IAaveV4ConfigEngine.AssetConfigUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateHubAssetIRs@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyHubSpokeCapsReverts(env e, IAaveV4ConfigEngine.SpokeConfigUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateHubSpokeCaps@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyReserveConfigsReverts(env e, IAaveV4ConfigEngine.ReserveConfigUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateReserveConfigs@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyDynamicReserveConfigsReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateDynamicReserveConfigs@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyAddDynamicReserveConfigsReverts(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions) {
    require e.msg.sender == RISK_COUNCIL() && additions.length == 0;

    // Execute the update
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptySpokeLiquidationConfigsReverts(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateSpokeLiquidationConfigs@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyLstPriceCapsReverts(env e, IRiskSteward.PriceCapLstUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateLstPriceCaps@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyStablePriceCapsReverts(env e, IRiskSteward.PriceCapStableUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updateStablePriceCaps@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}

rule emptyPendleDiscountRatesReverts(env e, IRiskSteward.DiscountRatePendleUpdate[] updates) {
    require e.msg.sender == RISK_COUNCIL() && updates.length == 0;

    // Execute the update
    updatePendleDiscountRates@withrevert(e, updates);

    // Assert that an empty batch reverts
    assert lastReverted;
}
