/*
 * RiskSteward — State transitions: protocol effects and magnitude bounds.
 *
 * Property: a successful update writes the submitted value, and the move from
 * the pre-tx protocol value is at most the configured maxPercentChange.
 */

import "../common/PercentMath.spec";

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

    // Interest-rate strategy getters (anchor + read-back for the asset-IR rules).
    function irH.getInterestRateData(uint256 assetId) external returns (IAssetInterestRateStrategy.InterestRateData) envfree;
    function irH.HUB() external returns (address) envfree;

    // Spoke getters.
    function spokeH.getReserveId(address hub, uint256 assetId) external returns (uint256) envfree;
    function spokeH.getReserveConfig(uint256 reserveId) external returns (ISpoke.ReserveConfig) envfree;
    function spokeH.getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey) external returns (ISpoke.DynamicReserveConfig) envfree;
    function spokeH.getLiquidationConfig() external returns (ISpoke.LiquidationConfig) envfree;
    function spokeH.latestDynamicConfigKey(uint256 reserveId) external returns (uint32) envfree;

    // Neutralize access control on the whole write path (see header).
    function AuthorityUtils.canCallWithDelay(address authority, address caller, address target, bytes4 selector) internal returns (bool, uint32) 
        => alwaysAllowed();

    // DISPATCHER(true): the engine copies the update array to memory, so callees
    // are symbolic. DISPATCHER case-splits over the scene contracts that implement
    // the sighash.
    function _.getAssetId(address) external => DISPATCHER(true);
    function _.getSpokeConfig(uint256, address) external => DISPATCHER(true);
    function _.getReserveId(address, uint256) external => DISPATCHER(true);
    function _.getReserveConfig(uint256) external => DISPATCHER(true);
    function _.getDynamicReserveConfig(uint256, uint32) external => DISPATCHER(true);
    function _.getReserve(uint256) external => DISPATCHER(true);
    function _.getLiquidationConfig() external => DISPATCHER(true);
    function _.getAssetConfig(uint256) external => DISPATCHER(true);
    function _.getInterestRateData(uint256) external => DISPATCHER(true);

    function _.updateSpokeCaps(address hub, uint256 assetId, address spoke, uint256 addCap, uint256 drawCap) external => DISPATCHER(true);
    function _.updateSpokeAddCap(address, uint256, address, uint256) external => DISPATCHER(true);
    function _.updateSpokeDrawCap(address, uint256, address, uint256) external => DISPATCHER(true);
    function _.updateCollateralRisk(address, uint256, uint256) external => DISPATCHER(true);
    function _.updateDynamicReserveConfig(address, uint256, uint32, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.addDynamicReserveConfig(address, uint256, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.updateLiquidationTargetHealthFactor(address, uint256) external => DISPATCHER(true);
    function _.updateHealthFactorForMaxBonus(address, uint256) external => DISPATCHER(true);
    function _.updateLiquidationBonusFactor(address, uint256) external => DISPATCHER(true);
    function _.updateLiquidationConfig(address, ISpoke.LiquidationConfig) external => DISPATCHER(true);
    function _.updateInterestRateData(address, uint256, bytes) external => DISPATCHER(true);

    // configurator -> Hub / Spoke storage
    function _.updateSpokeConfig(uint256, address, IHub.SpokeConfig) external => DISPATCHER(true);
    function _.updateReserveConfig(uint256, ISpoke.ReserveConfig) external => DISPATCHER(true);
    function _.updateDynamicReserveConfig(uint256, uint32, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.updateLiquidationConfig(ISpoke.LiquidationConfig) external => DISPATCHER(true);

    // Two hops share this signature — HubConfigurator -> Hub, then Hub -> strategy
    function _.setInterestRateData(uint256, bytes) external => DISPATCHER(true);

    // The IR curve is nonlinear in five uint256 inputs. No rule here asserts on its
    // return value so NONDET is ok.
    function _.calculateInterestRate(uint256, uint256, uint256, uint256, uint256) external => NONDET;

    // `percentMulDown` is inline assembly: a 256-bit `mul`, a `div`, and an overflow
    // guard. It is the only nonlinear step in `_updateWithinAllowedRange` (the rest is
    // a subtraction and a comparison) and the dominant SMT cost on this path, so it is
    // the only thing abstracted --- the predicate's own control flow stays real
    // Solidity. Equivalence proven in PercentMulDownEquivalence.spec.
    function PercentageMath.percentMulDown(uint256 value, uint256 percentage) internal returns (uint256)
        => percentMulDownCVL(value, percentage);

    // Explicit DISPATCH list.
    unresolved external in _._ => DISPATCH [
        HubConfiguratorHarness.updateSpokeCaps(address, uint256, address, uint256, uint256),
        HubConfiguratorHarness.updateSpokeAddCap(address, uint256, address, uint256),
        HubConfiguratorHarness.updateSpokeDrawCap(address, uint256, address, uint256),
        HubHarness.updateSpokeConfig(uint256, address, IHub.SpokeConfig),
        SpokeConfiguratorHarness.updateCollateralRisk(address, uint256, uint256),
        SpokeConfiguratorHarness.updateDynamicReserveConfig(address, uint256, uint32, ISpoke.DynamicReserveConfig),
        SpokeConfiguratorHarness.addDynamicReserveConfig(address, uint256, ISpoke.DynamicReserveConfig),
        SpokeConfiguratorHarness.updateLiquidationTargetHealthFactor(address, uint256),
        SpokeConfiguratorHarness.updateHealthFactorForMaxBonus(address, uint256),
        SpokeConfiguratorHarness.updateLiquidationBonusFactor(address, uint256),
        SpokeConfiguratorHarness.updateLiquidationConfig(address, ISpoke.LiquidationConfig),
        SpokeHarness.updateReserveConfig(uint256, ISpoke.ReserveConfig),
        SpokeHarness.updateDynamicReserveConfig(uint256, uint32, ISpoke.DynamicReserveConfig),
        SpokeHarness.addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig),
        SpokeHarness.updateLiquidationConfig(ISpoke.LiquidationConfig),
        HubConfiguratorHarness.updateInterestRateData(address, uint256, bytes),
        HubHarness.setInterestRateData(uint256, bytes),
        AssetInterestRateStrategyHarness.setInterestRateData(uint256, bytes)
    ] default HAVOC_ALL;
}

// KEEP_CURRENT = type(uint256).max - 652 = 2^256 - 653.
definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;

// The irData fields carry their own narrower sentinels (EngineFlags.sol:15-24).
definition KEEP_CURRENT_ADDRESS() returns address = 0xffffffffffffffffffffffffffffffffffffffff;
definition KEEP_CURRENT_UINT16() returns uint16 = 65474;      // type(uint16).max - 61
definition KEEP_CURRENT_UINT32() returns uint32 = 4294967272;  // type(uint32).max - 23

// Return (allowed, delay=0) so Hub/Spoke authority checks never revert here.
function alwaysAllowed() returns (bool, uint32) {
    return (true, 0);
}

// The bound `_updateWithinAllowedRange` enforces, in mathint so callers need no casts.
function allowedDiff(bool isRelative, mathint maxPercentChange, mathint from) returns mathint {
    return isRelative ? (from * maxPercentChange) / 10000 : maxPercentChange;
}

function absDiff(mathint a, mathint b) returns mathint {
    return a > b ? a - b : b - a;
}

// ---------------------------------------------------------------------------
// updateHubSpokeCaps : addCap / drawCap  (relative mode)
// ---------------------------------------------------------------------------

rule capsAddCapMagnitude(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the addCap before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    bool isRelative = getConfig().hub.cap.addCap.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.cap.addCap.maxPercentChange);
    mathint from = to_mathint(hubH.getSpokeConfig(assetId, u.spoke).addCap);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the addCap after the update
    mathint post = to_mathint(hubH.getSpokeConfig(assetId, u.spoke).addCap);

    // Assert that the change is within the configured bound
    assert u.addCap != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule capsDrawCapMagnitude(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    // Keeps the merged HubEngine.sol call inside the DISPATCH list
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the drawCap before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    bool isRelative = getConfig().hub.cap.drawCap.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().hub.cap.drawCap.maxPercentChange);
    mathint from = to_mathint(hubH.getSpokeConfig(assetId, u.spoke).drawCap);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the drawCap after the update
    mathint post = to_mathint(hubH.getSpokeConfig(assetId, u.spoke).drawCap);
    // Assert that the change is within the configured bound
    assert u.drawCap != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// updateReserveConfigs : collateralRisk
// ---------------------------------------------------------------------------

rule reserveCollateralRiskMagnitude(env e, IAaveV4ConfigEngine.ReserveConfigUpdate u) {
    // Create a valid ReserveConfigUpdate array
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;

    // Fetch the collateralRisk before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    bool isRelative = getConfig().spoke.collateralRisk.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.collateralRisk.maxPercentChange);
    mathint from = to_mathint(spokeH.getReserveConfig(reserveId).collateralRisk);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the collateralRisk after the update
    mathint post = to_mathint(spokeH.getReserveConfig(reserveId).collateralRisk);
    // Assert that the change is within the configured bound
    assert u.collateralRisk != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs : collateralFactor / maxLiquidationBonus
// ---------------------------------------------------------------------------

rule dynUpdateCollateralFactorMagnitude(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {

    // Create a valid DynamicReserveConfigUpdate array
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;

    // Fetch the collateralFactor before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);
    bool isRelative = getConfig().spoke.dynamicUpdate.collateralFactor.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicUpdate.collateralFactor.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the collateralFactor after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor);
    // Assert that the change is within the configured bound
    assert u.collateralFactor != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule dynUpdateMaxLiquidationBonusMagnitude(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {
    // Create a valid DynamicReserveConfigUpdate array
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;

    // Fetch the maxLiquidationBonus before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);
    bool isRelative = getConfig().spoke.dynamicUpdate.maxLiquidationBonus.isChangeRelative;
    mathint maxPercentChange = to_mathint(getConfig().spoke.dynamicUpdate.maxLiquidationBonus.maxPercentChange);
    mathint from = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the maxLiquidationBonus after the update
    mathint post = to_mathint(spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus);
    // Assert that the change is within the configured bound
    assert u.maxLiquidationBonus != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ---------------------------------------------------------------------------
// addDynamicReserveConfigs : collateralFactor / maxLiquidationBonus
//
// Anchored to the latest existing key, not to the appended slot — see header.
// No sentinel exists for additions, so every successful addition is in scope.
// ---------------------------------------------------------------------------

rule dynAddCollateralFactorMagnitude(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition a) {
    // Create a valid DynamicReserveConfigAddition array
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;

    // Fetch the collateralFactor of the latest key before the update
    uint256 assetId = hubH.getAssetId(a.underlying);
    uint256 reserveId = spokeH.getReserveId(a.hub, assetId);
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

rule dynAddMaxLiquidationBonusMagnitude(env e, IAaveV4ConfigEngine.DynamicReserveConfigAddition a) {
    // Create a valid DynamicReserveConfigAddition array
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;

    // Fetch the maxLiquidationBonus of the latest key before the update
    uint256 assetId = hubH.getAssetId(a.underlying);
    uint256 reserveId = spokeH.getReserveId(a.hub, assetId);
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

// ---------------------------------------------------------------------------
// addDynamicReserveConfigs
// ---------------------------------------------------------------------------

// liquidationFee is frozen by equality against `ref`,not by a KEEP_CURRENT sentinel
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

// An addition must extend an existing dynamic config, never bootstrap one (NoExistingDynamicConfig). 
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
// updateSpokeLiquidationConfigs : three fields
// ---------------------------------------------------------------------------

rule liqTargetHealthFactorMagnitude(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
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
    assert u.targetHealthFactor != KEEP_CURRENT()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

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
// updateHubAssetIRs : the four interest-rate data fields
// ---------------------------------------------------------------------------

rule assetIROptimalUsageRatioMagnitude(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    uint256 assetId = hubH.getAssetId(u.underlying);

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
    assert u.irData.optimalUsageRatio != KEEP_CURRENT_UINT16()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule assetIRBaseDrawnRateMagnitude(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    uint256 assetId = hubH.getAssetId(u.underlying);

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
    assert u.irData.baseDrawnRate != KEEP_CURRENT_UINT32()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule assetIRRateGrowthBeforeOptimalMagnitude(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    uint256 assetId = hubH.getAssetId(u.underlying);

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
    assert u.irData.rateGrowthBeforeOptimal != KEEP_CURRENT_UINT32()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

rule assetIRRateGrowthAfterOptimalMagnitude(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    uint256 assetId = hubH.getAssetId(u.underlying);

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
    assert u.irData.rateGrowthAfterOptimal != KEEP_CURRENT_UINT32()
        => absDiff(post, from) <= allowedDiff(isRelative, maxPercentChange, from);
}

// ===========================================================================
// Effect fidelity: a successful non-sentinel submission writes the requested
// value to the real Hub/Spoke protocol state.
// ===========================================================================

// ---------------------------------------------------------------------------
// updateHubSpokeCaps : addCap / drawCap
// ---------------------------------------------------------------------------

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
// updateReserveConfigs : collateralRisk
// ---------------------------------------------------------------------------

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
// updateDynamicReserveConfigs : collateralFactor / maxLiquidationBonus
// ---------------------------------------------------------------------------

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
// updateSpokeLiquidationConfigs : three fields
// ---------------------------------------------------------------------------

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
// updateHubAssetIRs : the four interest-rate data fields
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
