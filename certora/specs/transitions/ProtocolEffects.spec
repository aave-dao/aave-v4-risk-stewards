/*
 * RiskSteward — State transitions: protocol effects and magnitude bounds.
 *
 * Property: a successful update writes the submitted value, and the move from
 * the pre-tx protocol value is at most the configured maxPercentChange.
 *
*/

import "../common/PercentMath.spec";

// Write-path resolution for the full scene: the authority bypass, the DISPATCHER
// summaries, the DISPATCH list, and the KEEP_CURRENT sentinels.
import "../common/SceneDispatch.spec";

using HubHarness as hubH;
using SpokeHarness as spokeH;
using HubConfiguratorHarness as hubConfig;
using SpokeConfiguratorHarness as spokeConfig;
using AssetInterestRateStrategyHarness as irH;

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;

    // Hub getters.
    function hubH.getAssetId(address underlying) external returns (uint256) envfree;
    function hubH.isUnderlyingListed(address underlying) external returns (bool) envfree;
    function hubH.getSpokeConfig(uint256 assetId, address spoke) external returns (IHub.SpokeConfig) envfree;
    function hubH.getAssetConfig(uint256 assetId) external returns (IHub.AssetConfig) envfree;

    // Interest-rate strategy read-back for the asset-IR rules.
    function irH.getInterestRateData(uint256 assetId) external returns (IAssetInterestRateStrategy.InterestRateData) envfree;

    // Spoke getters.
    function spokeH.getReserveId(address hub, uint256 assetId) external returns (uint256) envfree;
    function spokeH.getReserveConfig(uint256 reserveId) external returns (ISpoke.ReserveConfig) envfree;
    function spokeH.getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey) external returns (ISpoke.DynamicReserveConfig) envfree;
    function spokeH.getLiquidationConfig() external returns (ISpoke.LiquidationConfig) envfree;
    function spokeH.latestDynamicConfigKey(uint256 reserveId) external returns (uint32) envfree;

    // `percentMulDown` is inline assembly: a 256-bit `mul`, a `div`, and an overflow
    // guard. It is the only nonlinear step in `_updateWithinAllowedRange` (the rest is
    // a subtraction and a comparison) and the dominant SMT cost on this path, so it is
    // the only thing abstracted --- the predicate's own control flow stays real
    // Solidity. Equivalence proven in PercentMulDownEquivalence.spec.
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal returns (uint256)
        => percentMulDownCVL(value, percentage);
}

// The irData fields carry their own narrower sentinels (EngineFlags.sol:15-24).
definition KEEP_CURRENT_UINT16() returns uint16 = 65474;      // type(uint16).max - 61
definition KEEP_CURRENT_UINT32() returns uint32 = 4294967272;  // type(uint32).max - 23

// The bound `_updateWithinAllowedRange` enforces, in mathint so callers need no casts.
function allowedDiff(bool isRelative, mathint maxPercentChange, mathint from) returns mathint {
    return isRelative ? (from * maxPercentChange) / 10000 : maxPercentChange;
}

function absDiff(mathint a, mathint b) returns mathint {
    return a > b ? a - b : b - a;
}

// ---------------------------------------------------------------------------
// updateHubSpokeCaps 
// ---------------------------------------------------------------------------

// Make sure add cap moves within the configured bound
rule capsAddCapMagnitude(env e, uint256 assetId, address spoke) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the addCap before the update
    bool isRelative = getConfig().hub.cap.addCap.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.cap.addCap.maxPercentChange);
    mathint from = to_mathint(hubH.getSpokeConfig(assetId, spoke).addCap);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the addCap after the update
    mathint post = to_mathint(hubH.getSpokeConfig(assetId, spoke).addCap);

    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure draw cap moves within the configured bound
rule capsDrawCapMagnitude(env e, uint256 assetId, address spoke) {
    // Keeps the merged HubEngine.sol call inside the DISPATCH list
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the drawCap before the update
    bool isRelative = getConfig().hub.cap.drawCap.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.cap.drawCap.maxPercentChange);
    mathint from = to_mathint(hubH.getSpokeConfig(assetId, spoke).drawCap);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the drawCap after the update
    mathint post = to_mathint(hubH.getSpokeConfig(assetId, spoke).drawCap);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// updateReserveConfigs
// ---------------------------------------------------------------------------

// Make sure collateral risk moves within the configured bound
rule reserveCollateralRiskMagnitude(env e, uint256 reserveId) {
    // Create a valid ReserveConfigUpdate array
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;

    // Fetch the collateralRisk before the update
    bool isRelative = getConfig().spoke.collateralRisk.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.collateralRisk.maxPercentChange);
    mathint from = to_mathint(spokeH.getReserveConfig(reserveId).collateralRisk);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the collateralRisk after the update
    mathint post = to_mathint(spokeH.getReserveConfig(reserveId).collateralRisk);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs 
// ---------------------------------------------------------------------------

// Make sure collateral factor moves within the configured bound
rule dynUpdateCollateralFactorMagnitude(env e, uint256 reserveId, uint32 key) {

    // Create a valid DynamicReserveConfigUpdate array
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;

    // Fetch the collateralFactor before the update
    bool isRelative = getConfig().spoke.dynamicUpdate.collateralFactor.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicUpdate.collateralFactor.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the collateralFactor after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure max bonus moves within the configured bound
rule dynUpdateMaxLiquidationBonusMagnitude(env e, uint256 reserveId, uint32 key) {
    // Create a valid DynamicReserveConfigUpdate array
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;

    // Fetch the maxLiquidationBonus before the update
    bool isRelative = getConfig().spoke.dynamicUpdate.maxLiquidationBonus.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicUpdate.maxLiquidationBonus.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the maxLiquidationBonus after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// addDynamicReserveConfigs 
// ---------------------------------------------------------------------------

// Make sure collateral factor moves within the configured bound
rule dynAddCollateralFactorMagnitude(env e, uint256 reserveId) {
    // Create a valid DynamicReserveConfigAddition array
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;

    // Fetch the collateralFactor of the latest key before the update
    bool isRelative = getConfig().spoke.dynamicAdd.collateralFactor.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicAdd.collateralFactor.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).collateralFactor);

    // Execute the update
    addDynamicReserveConfigs(e, additions);

    // Fetch the collateralFactor of the latest key after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).collateralFactor);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure max bonus moves within the configured bound
rule dynAddMaxLiquidationBonusMagnitude(env e, uint256 reserveId) {
    // Create a valid DynamicReserveConfigAddition array
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;

    // Fetch the maxLiquidationBonus of the latest key before the update
    bool isRelative = getConfig().spoke.dynamicAdd.maxLiquidationBonus.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicAdd.maxLiquidationBonus.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).maxLiquidationBonus);

    // Execute the update
    addDynamicReserveConfigs(e, additions);

    // Fetch the maxLiquidationBonus of the latest key after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).maxLiquidationBonus);
    
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure liquidation fee does not move
rule dynAddLiquidationFeeFrozen(env e) {

    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require additions.length == 1 && additions[0].spoke == spokeH && additions[0].hub == hubH;
    require getConfig().spoke.configurator == spokeConfig, "Keeps the SpokeEngine hop dispatched";

    uint256 reserveId = spokeH.getReserveId(additions[0].hub, hubH.getAssetId(additions[0].underlying));
    uint16 refFee = spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).liquidationFee;
    uint16 newFee = additions[0].dynamicConfig.liquidationFee;

    // Execute the addition
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that changing liquidationFee causes a revert
    assert newFee != refFee => lastReverted;
}

// An addition must extend an existing dynamic config, never bootstrap one 
rule dynAddRequiresExistingConfig(env e) {

    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require additions.length == 1 && additions[0].spoke == spokeH && additions[0].hub == hubH;
    require getConfig().spoke.configurator == spokeConfig, "Keeps the SpokeEngine hop dispatched";

    uint256 reserveId = spokeH.getReserveId(additions[0].hub, hubH.getAssetId(additions[0].underlying));
    uint16 refFactor = spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).collateralFactor;

    // Execute the addition
    addDynamicReserveConfigs@withrevert(e, additions);

    // Assert that an absent reference config causes a revert
    assert refFactor == 0 => lastReverted;
}

// ---------------------------------------------------------------------------
// updateSpokeLiquidationConfigs 
// ---------------------------------------------------------------------------

// Make sure target health factor moves within the configured bound
rule liqTargetHealthFactorMagnitude(env e) {
    // Create a valid LiquidationConfigUpdate array
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;

    // Fetch the targetHealthFactor before the update
    bool isRelative = getConfig().spoke.liquidation.targetHealthFactor.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.liquidation.targetHealthFactor.maxPercentChange);
    mathint from = to_mathint(spokeH.getLiquidationConfig().targetHealthFactor);

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the targetHealthFactor after the update
    mathint post = to_mathint(spokeH.getLiquidationConfig().targetHealthFactor);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure health factor for max bonus moves within the configured bound
rule liqHealthFactorForMaxBonusMagnitude(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    // Pin sibling liquidation fields to KEEP_CURRENT so their validations
    // early-return and their writes no-op, leaving only the current field live.
    // (Prover Performances Helper)
    require u.targetHealthFactor == KEEP_CURRENT() && u.liquidationBonusFactor == KEEP_CURRENT();

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke // Prover Performances
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Fetch the healthFactorForMaxBonus before the update
    bool isRelative = getConfig().spoke.liquidation.healthFactorForMaxBonus.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.liquidation.healthFactorForMaxBonus.maxPercentChange);
    mathint from = to_mathint(spokeH.getLiquidationConfig().healthFactorForMaxBonus);

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the healthFactorForMaxBonus after the update
    mathint post = to_mathint(spokeH.getLiquidationConfig().healthFactorForMaxBonus);
    // Assert that the change is within the configured bound
    assert u.healthFactorForMaxBonus != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure liquidation bonus factor moves within the configured bound
rule liqBonusFactorMagnitude(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    // Pin sibling liquidation fields to KEEP_CURRENT so their validations
    // early-return and their writes no-op, leaving only the current field live.
    // (Prover Performances Helper)
    require u.targetHealthFactor == KEEP_CURRENT() && u.healthFactorForMaxBonus == KEEP_CURRENT();

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Fetch the liquidationBonusFactor before the update
    bool isRelative = getConfig().spoke.liquidation.liquidationBonusFactor.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.liquidation.liquidationBonusFactor.maxPercentChange);
    mathint from = to_mathint(spokeH.getLiquidationConfig().liquidationBonusFactor);

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the liquidationBonusFactor after the update
    mathint post = to_mathint(spokeH.getLiquidationConfig().liquidationBonusFactor);
    // Assert that the change is within the configured bound
    assert u.liquidationBonusFactor != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// updateHubAssetIRs 
// ---------------------------------------------------------------------------

// Make sure optimal usage ratio moves within the configured bound
rule assetIROptimalUsageRatioMagnitude(env e, uint256 assetId) {
    // Create a valid AssetConfigUpdate array
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the optimalUsageRatio before the update
    bool isRelative = getConfig().hub.rate.optimalUsageRatio.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.rate.optimalUsageRatio.maxPercentChange);
    mathint from = to_mathint(irH.getInterestRateData(assetId).optimalUsageRatio);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the optimalUsageRatio after the update
    mathint post = to_mathint(irH.getInterestRateData(assetId).optimalUsageRatio);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure base drawn rate moves within the configured bound
rule assetIRBaseDrawnRateMagnitude(env e, uint256 assetId) {
    // Create a valid AssetConfigUpdate array
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the baseDrawnRate before the update
    bool isRelative = getConfig().hub.rate.baseDrawnRate.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.rate.baseDrawnRate.maxPercentChange);
    mathint from = to_mathint(irH.getInterestRateData(assetId).baseDrawnRate);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the baseDrawnRate after the update
    mathint post = to_mathint(irH.getInterestRateData(assetId).baseDrawnRate);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure rate growth before optimal moves within the configured bound
rule assetIRRateGrowthBeforeOptimalMagnitude(env e, uint256 assetId) {
    // Create a valid AssetConfigUpdate array
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the rateGrowthBeforeOptimal before the update
    bool isRelative = getConfig().hub.rate.rateGrowthBeforeOptimal.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.rate.rateGrowthBeforeOptimal.maxPercentChange);
    mathint from = to_mathint(irH.getInterestRateData(assetId).rateGrowthBeforeOptimal);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the rateGrowthBeforeOptimal after the update
    mathint post = to_mathint(irH.getInterestRateData(assetId).rateGrowthBeforeOptimal);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// Make sure rate growth after optimal moves within the configured bound
rule assetIRRateGrowthAfterOptimalMagnitude(env e, uint256 assetId) {
    // Create a valid AssetConfigUpdate array
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the rateGrowthAfterOptimal before the update
    bool isRelative = getConfig().hub.rate.rateGrowthAfterOptimal.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.rate.rateGrowthAfterOptimal.maxPercentChange);
    mathint from = to_mathint(irH.getInterestRateData(assetId).rateGrowthAfterOptimal);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the rateGrowthAfterOptimal after the update
    mathint post = to_mathint(irH.getInterestRateData(assetId).rateGrowthAfterOptimal);
    // Assert that the change is within the configured bound
    assert absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ===========================================================================
// Effect fidelity: a successful non-sentinel submission writes the requested
// value to the real Hub/Spoke protocol state.
// ===========================================================================

// ---------------------------------------------------------------------------
// updateHubSpokeCaps 
// ---------------------------------------------------------------------------

// Make sure add cap is written to the Hub
rule spokeCapsAddCapFidelity(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1 && updates[0].hub == u.hub
        && updates[0].spoke == u.spoke && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Execute the update
    updateHubSpokeCaps(e, updates);

    uint256 assetId = hubH.getAssetId(u.underlying);
    // Assert that a non-sentinel addCap was written to the Hub
    assert u.addCap != KEEP_CURRENT() 
        => to_mathint(hubH.getSpokeConfig(assetId, u.spoke).addCap) == to_mathint(u.addCap);
}

// Make sure draw cap is written to the Hub
rule spokeCapsDrawCapFidelity(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1 && updates[0].hub == u.hub
        && updates[0].spoke == u.spoke && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Execute the update
    updateHubSpokeCaps(e, updates);

    uint256 assetId = hubH.getAssetId(u.underlying);
    // Assert that a non-sentinel drawCap was written to the Hub
    assert u.drawCap != KEEP_CURRENT() 
        => to_mathint(hubH.getSpokeConfig(assetId, u.spoke).drawCap) == to_mathint(u.drawCap);
}

// ---------------------------------------------------------------------------
// updateReserveConfigs 
// ---------------------------------------------------------------------------

// Make sure collateral risk is written to the Spoke
rule reserveCollateralRiskFidelity(env e, IAaveV4ConfigEngine.ReserveConfigUpdate u) {
    // Create a valid ReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].collateralRisk == u.collateralRisk
        && updates[0].spokeConfigurator == u.spokeConfigurator
        && updates[0].priceSource == u.priceSource
        && updates[0].paused == u.paused && updates[0].frozen == u.frozen
        && updates[0].borrowable == u.borrowable
        && updates[0].receiveSharesEnabled == u.receiveSharesEnabled;

    // Execute the update
    updateReserveConfigs(e, updates);

    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);

    // Assert that a non-sentinel collateralRisk was written to the Spoke
    assert u.collateralRisk != KEEP_CURRENT() 
        => to_mathint(spokeH.getReserveConfig(reserveId).collateralRisk) == to_mathint(u.collateralRisk);
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs 
// ---------------------------------------------------------------------------

// Make sure collateral factor is written to the Spoke
rule dynUpdateCollateralFactorFidelity(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {
    // Create a valid DynamicReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].dynamicConfigKey == u.dynamicConfigKey
        && updates[0].collateralFactor == u.collateralFactor
        && updates[0].maxLiquidationBonus == u.maxLiquidationBonus
        && updates[0].liquidationFee == u.liquidationFee
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);

    // Assert that a non-sentinel collateralFactor was written to the Spoke
    assert u.collateralFactor != KEEP_CURRENT() 
        => to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor) == to_mathint(u.collateralFactor);
}

// Make sure max bonus is written to the Spoke
rule dynUpdateMaxLiquidationBonusFidelity(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {
    // Create a valid DynamicReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].dynamicConfigKey == u.dynamicConfigKey
        && updates[0].collateralFactor == u.collateralFactor
        && updates[0].maxLiquidationBonus == u.maxLiquidationBonus
        && updates[0].liquidationFee == u.liquidationFee
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);
    // Assert that a non-sentinel maxLiquidationBonus was written to the Spoke
    assert u.maxLiquidationBonus != KEEP_CURRENT() 
        => to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus) == to_mathint(u.maxLiquidationBonus);
}

// ---------------------------------------------------------------------------
// addDynamicReserveConfigs 
// ---------------------------------------------------------------------------

// Constrain a singleton DynamicReserveConfigAddition batch to the input.
function dynAddBatch(IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions, IAaveV4ConfigEngine.DynamicReserveConfigAddition a) returns bool {
    return additions.length == 1 && additions[0].spoke == a.spoke
        && additions[0].hub == a.hub && additions[0].underlying == a.underlying
        && additions[0].spokeConfigurator == a.spokeConfigurator
        && additions[0].dynamicConfig.collateralFactor == a.dynamicConfig.collateralFactor
        && additions[0].dynamicConfig.maxLiquidationBonus == a.dynamicConfig.maxLiquidationBonus
        && additions[0].dynamicConfig.liquidationFee == a.dynamicConfig.liquidationFee;
}

// Make sure collateral factor is written to the Spoke
rule dynAddCollateralFactorFidelity(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition a) {
    require getConfig().spoke.configurator == spokeConfig, "Keeps the SpokeEngine hop dispatched";
    require a.spoke == spokeH && a.hub == hubH, "Pins the addition to the snapshotted scene contracts";

    // Create a valid DynamicReserveConfigAddition array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require dynAddBatch(additions, a);

    // Execute the addition
    addDynamicReserveConfigs(e, additions);

    uint256 assetId = hubH.getAssetId(a.underlying);
    uint256 reserveId = spokeH.getReserveId(a.hub, assetId);

    // Assert that the submitted collateralFactor was written to the appended key
    assert spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).collateralFactor
        == a.dynamicConfig.collateralFactor;
}

// Make sure max bonus is written to the Spoke
rule dynAddMaxLiquidationBonusFidelity(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition a) {
    require getConfig().spoke.configurator == spokeConfig, "Keeps the SpokeEngine hop dispatched";
    require a.spoke == spokeH && a.hub == hubH, "Pins the addition to the snapshotted scene contracts";

    // Create a valid DynamicReserveConfigAddition array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require dynAddBatch(additions, a);

    // Execute the addition
    addDynamicReserveConfigs(e, additions);

    uint256 assetId = hubH.getAssetId(a.underlying);
    uint256 reserveId = spokeH.getReserveId(a.hub, assetId);

    // Assert that the submitted maxLiquidationBonus was written to the appended key
    assert spokeH.getDynamicReserveConfig(reserveId, spokeH.latestDynamicConfigKey(reserveId)).maxLiquidationBonus
        == a.dynamicConfig.maxLiquidationBonus;
}

// ---------------------------------------------------------------------------
// updateSpokeLiquidationConfigs
// ---------------------------------------------------------------------------

// Make sure target health factor is written to the Spoke
rule liqTargetHealthFactorFidelity(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that a non-sentinel targetHealthFactor was written to the Spoke
    assert u.targetHealthFactor != KEEP_CURRENT() 
        => to_mathint(spokeH.getLiquidationConfig().targetHealthFactor) == to_mathint(u.targetHealthFactor);
}

// Make sure health factor for max bonus is written to the Spoke
rule liqHealthFactorForMaxBonusFidelity(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    require e.msg.sender == RISK_COUNCIL(),"Require the caller to be the RiskCouncil (Prover Performances Helper)";
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";
    require u.spoke == spokeH && u.spokeConfigurator == spokeConfig, "Require the spoke and spoke configurator to be the same as the input";

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Pin sibling liquidation fields to KEEP_CURRENT so their validations
    // early-return and their writes no-op, leaving only the current field live.
    // (Prover Performances Helper)
    require u.targetHealthFactor == KEEP_CURRENT() && u.liquidationBonusFactor == KEEP_CURRENT();

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that a non-sentinel healthFactorForMaxBonus was written to the Spoke
    assert u.healthFactorForMaxBonus != KEEP_CURRENT() 
        => to_mathint(spokeH.getLiquidationConfig().healthFactorForMaxBonus) == to_mathint(u.healthFactorForMaxBonus);
}

// Make sure liquidation bonus factor is written to the Spoke
rule liqBonusFactorFidelity(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    require e.msg.sender == RISK_COUNCIL(); // Prover Performances Helper
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";
    require u.spoke == spokeH && u.spokeConfigurator == spokeConfig; // Prover Performances Helper

    // Pin sibling liquidation fields to KEEP_CURRENT so their validations
    // early-return and their writes no-op, leaving only the current field live.
    // (Prover Performances Helper)
    require u.targetHealthFactor == KEEP_CURRENT() && u.healthFactorForMaxBonus == KEEP_CURRENT();

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Assert that a non-sentinel liquidationBonusFactor was written to the Spoke
    assert u.liquidationBonusFactor != KEEP_CURRENT() 
        => to_mathint(spokeH.getLiquidationConfig().liquidationBonusFactor) == to_mathint(u.liquidationBonusFactor);
}

// ---------------------------------------------------------------------------
// updateHubAssetIRs 
// ---------------------------------------------------------------------------

// Constrain a singleton AssetConfigUpdate batch to the input.
function assetIRBatch(IAaveV4ConfigEngine.AssetConfigUpdate[] updates, IAaveV4ConfigEngine.AssetConfigUpdate u) returns bool {
    return updates.length == 1 && updates[0].hub == u.hub
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].underlying == u.underlying
        && updates[0].liquidityFee == u.liquidityFee
        && updates[0].feeReceiver == u.feeReceiver
        && updates[0].irStrategy == u.irStrategy
        && updates[0].reinvestmentController == u.reinvestmentController
        && updates[0].irData.optimalUsageRatio == u.irData.optimalUsageRatio
        && updates[0].irData.baseDrawnRate == u.irData.baseDrawnRate
        && updates[0].irData.rateGrowthBeforeOptimal == u.irData.rateGrowthBeforeOptimal
        && updates[0].irData.rateGrowthAfterOptimal == u.irData.rateGrowthAfterOptimal;
}

// Make sure optimal usage ratio is written to the strategy
rule assetIROptimalUsageRatioFidelity(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    // Fetch the assetId of underlying asset
    uint256 assetId = hubH.getAssetId(u.underlying);

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require assetIRBatch(updates, u);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that a non-sentinel optimalUsageRatio was written to the strategy
    assert u.irData.optimalUsageRatio != KEEP_CURRENT_UINT16()
        => irH.getInterestRateData(assetId).optimalUsageRatio == u.irData.optimalUsageRatio;
}

// Make sure base drawn rate is written to the strategy
rule assetIRBaseDrawnRateFidelity(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    // Fetch the assetId of underlying asset
    uint256 assetId = hubH.getAssetId(u.underlying);

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require assetIRBatch(updates, u);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that a non-sentinel baseDrawnRate was written to the strategy
    assert u.irData.baseDrawnRate != KEEP_CURRENT_UINT32()
        => irH.getInterestRateData(assetId).baseDrawnRate == u.irData.baseDrawnRate;
}

// Make sure rate growth before optimal is written to the strategy
rule assetIRRateGrowthBeforeOptimalFidelity(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    // Fetch the assetId of underlying asset
    uint256 assetId = hubH.getAssetId(u.underlying);

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require assetIRBatch(updates, u);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that a non-sentinel rateGrowthBeforeOptimal was written to the strategy
    assert u.irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32()
        => irH.getInterestRateData(assetId).rateGrowthBeforeOptimal == u.irData.rateGrowthBeforeOptimal;
}

// Make sure rate growth after optimal is written to the strategy
rule assetIRRateGrowthAfterOptimalFidelity(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    // Fetch the assetId of underlying asset
    uint256 assetId = hubH.getAssetId(u.underlying);

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require assetIRBatch(updates, u);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Assert that a non-sentinel rateGrowthAfterOptimal was written to the strategy
    assert u.irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32()
        => irH.getInterestRateData(assetId).rateGrowthAfterOptimal == u.irData.rateGrowthAfterOptimal;
}
