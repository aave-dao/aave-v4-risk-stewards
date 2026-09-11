/*
 * RiskSteward — State transitions: non-interference and immutability.
 *
 * Property: a successful RiskSteward call only changes the fields it's meant to.
 * Every other field, for every (assetId, spoke) key, is left untouched.
 */

// Dispatch rules to handle the out-of-scene oracle.
import "../common/SceneDispatch.spec";

using HubHarness as hubH;
using HubConfiguratorHarness as hubConfig;
using SpokeHarness as spokeH;
using SpokeConfiguratorHarness as spokeConfig;
using AssetInterestRateStrategyHarness as irH;

methods {
    function RISK_COUNCIL() external returns (address) envfree;
    function getConfig() external returns (IRiskSteward.Config) envfree;
    function hubH.getAssetConfig(uint256 assetId) external returns (IHub.AssetConfig) envfree;
    function hubH.getSpokeConfig(uint256 assetId, address spoke) external returns (IHub.SpokeConfig) envfree;
    function hubH.getAssetId(address underlying) external returns (uint256) envfree;
    function hubH.isUnderlyingListed(address underlying) external returns (bool) envfree;
    function spokeH.getReserveId(address hub, uint256 assetId) external returns (uint256) envfree;
    function spokeH.getReserveConfig(uint256 reserveId) external returns (ISpoke.ReserveConfig) envfree;
    function spokeH.getDynamicReserveConfig(uint256 reserveId, uint32 dynamicConfigKey) external returns (ISpoke.DynamicReserveConfig) envfree;
    function spokeH.getLiquidationConfig() external returns (ISpoke.LiquidationConfig) envfree;
    function spokeH.latestDynamicConfigKey(uint256 reserveId) external returns (uint32) envfree;
    function irH.getInterestRateData(uint256 assetId) external returns (IAssetInterestRateStrategy.InterestRateData) envfree;

    // Dropping these only adds executions: they gate or compute, never write the fields
    // asserted below, so removing them cannot hide a forbidden write. `_validateParamUpdate`
    // is the debounce/bounds gate — those live in DebounceStamping.spec and ProtocolEffects.spec.
    function RiskSteward._validateParamUpdate(IRiskSteward.ParamUpdateValidationInput memory) internal => NONDET;
    function AssetLogic.getDrawnIndex(IHub.Asset storage) internal returns (uint256) => NONDET;
    function AssetLogic.getUnrealizedFees(IHub.Asset storage, uint256) internal returns (uint256) => NONDET;
    function Hub._mintFeeShares(IHub.Asset storage, uint256) internal returns (uint256) => NONDET;

    // priceSource lives in the out-of-scene oracle, so we can detect attempted writes.
    function _.setReserveSource(uint256 reserveId, address source) external 
        => markPriceSource() expect void;

    // `=> anyIRData()` rather than `=> NONDET`: CVL rejects NONDET on a reference return type. 
    function RiskSteward._getCurrentIRData(address, address) internal returns (IAssetInterestRateStrategy.InterestRateData memory) 
        => anyIRData();
}

// The irData fields carry their own narrower sentinels
definition KEEP_CURRENT_UINT16() returns uint16 = 65474;       // type(uint16).max - 61
definition KEEP_CURRENT_UINT32() returns uint32 = 4294967272;  // type(uint32).max - 23

function anyIRData() returns IAssetInterestRateStrategy.InterestRateData {
    IAssetInterestRateStrategy.InterestRateData d;
    return d;
}

// ---------------------------------------------------------------------------
// updateHubAssetIRs path: liquidityFee / feeReceiver / irStrategy / reinvestmentController
// ---------------------------------------------------------------------------

// Verify that the hub asset IR fields are not touched
rule hubKeepsOutOfScopeFields(env e, uint256 assetId) {
    // Create a valid AssetConfigUpdate array
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;

    // Fetch the AssetConfig before the update
    IHub.AssetConfig before = hubH.getAssetConfig(assetId);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the AssetConfig after the update
    IHub.AssetConfig after = hubH.getAssetConfig(assetId);
    assert after.liquidityFee == before.liquidityFee;
    assert after.feeReceiver == before.feeReceiver;
    assert after.irStrategy == before.irStrategy;
    assert after.reinvestmentController == before.reinvestmentController;
}

// ---------------------------------------------------------------------------
// updateHubSpokeCaps path: riskPremiumThreshold / active / halted
// ---------------------------------------------------------------------------

// Verify that the hub spoke caps fields are not touched
rule capsKeepsOutOfScopeFields(env e, uint256 assetId, address spoke) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";
   
    // Create a valid SpokeConfigUpdate array
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;

    // Fetch the SpokeConfig before the update
    IHub.SpokeConfig before = hubH.getSpokeConfig(assetId, spoke);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    IHub.SpokeConfig after = hubH.getSpokeConfig(assetId, spoke);
    // addCap / drawCap are allowlisted; only the three out-of-scope fields are asserted.
    assert after.riskPremiumThreshold == before.riskPremiumThreshold;
    assert after.active == before.active;
    assert after.halted == before.halted;
}

// ===========================================================================
// Spoke forbidden-field immutability
// ===========================================================================

// Track if the price source was touched
ghost bool priceSourceTouched;

// Summary to Mark the price source as touched
function markPriceSource() { priceSourceTouched = true; }

// ---------------------------------------------------------------------------
// updateReserveConfigs path: priceSource + the four reserve flags
// ---------------------------------------------------------------------------

// Verify that the price source is not touched
rule reserveKeepsPriceSource(env e) {
    // Require the caller to be the RiskCouncil (Prover Performances Helper)
    require e.msg.sender == RISK_COUNCIL();
    
    // Pins the configurator RiskSteward will itself demand of every element.
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

    // Create a valid ReserveConfigUpdate array
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require updates.length == 1,"Limit batch updates elements to 1 for prover performances";
    
    require !priceSourceTouched,"Require satisfying fresh start";

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that the price source was not touched
    assert !priceSourceTouched;
}

// Verify that the immutable parameters from reserve config are not touched
rule reserveKeepsFlags(env e, uint256 reserveId) {
    // Require the caller to be the RiskCouncil (Prover Performances Helper)
    require e.msg.sender == RISK_COUNCIL();

    // Pins the configurator RiskSteward will itself demand of every element.
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

    // Create a valid ReserveConfigUpdate array
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require updates.length == 1,"Limit batch updates elements to 1 for prover performances";

    // Fetch the ReserveConfig before the update
    ISpoke.ReserveConfig before = spokeH.getReserveConfig(reserveId);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the ReserveConfig after the update
    ISpoke.ReserveConfig after = spokeH.getReserveConfig(reserveId);

    // Assert that the flags were not touched
    assert after.paused == before.paused && after.frozen == before.frozen
        && after.borrowable == before.borrowable && after.receiveSharesEnabled == before.receiveSharesEnabled;
}

// ---------------------------------------------------------------------------
// updateDynamicReserveConfigs path: liquidationFee
// ---------------------------------------------------------------------------

// Verify that the liquidation fee is not touched
rule dynKeepsLiquidationFee(env e, uint256 reserveId, uint32 key) {
    // Create a valid DynamicReserveConfigUpdate array
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length <= 2,"Limit batch updates elements to 2 for prover performances";

    // Fetch the DynamicReserveConfig before the update
    uint16 before = spokeH.getDynamicReserveConfig(reserveId, key).liquidationFee;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the DynamicReserveConfig after the update
    assert spokeH.getDynamicReserveConfig(reserveId, key).liquidationFee == before;
}


// Verify that the pre-existing keys are not touched
rule dynAddKeepsEarlierKeys(env e, uint256 reserveId, uint32 key) {
    // Pins the configurator RiskSteward will itself demand of every element.
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

    // Create a valid DynamicReserveConfigAddition array
    IAaveV4ConfigEngine.DynamicReserveConfigAddition[] additions;
    require additions.length <= 2,"Limit batch additions elements to 2 for prover performances";

    // Any key already in use before the call: the append lands strictly above it.
    require key <= spokeH.latestDynamicConfigKey(reserveId);

    // Fetch the DynamicReserveConfig before the addition
    ISpoke.DynamicReserveConfig before = spokeH.getDynamicReserveConfig(reserveId, key);

    // Execute the addition
    addDynamicReserveConfigs(e, additions);

    // Fetch the DynamicReserveConfig after the addition
    ISpoke.DynamicReserveConfig after = spokeH.getDynamicReserveConfig(reserveId, key);

    // Assert that the pre-existing key was left untouched
    assert after.collateralFactor == before.collateralFactor
        && after.maxLiquidationBonus == before.maxLiquidationBonus
        && after.liquidationFee == before.liquidationFee;
}

// ---------------------------------------------------------------------------
// (i) FIELD isolation — same key, sibling field untouched
// ---------------------------------------------------------------------------

// Verify that a sentinel interest-rate field is never written.
rule irKeepsSentinelFields(env e, IAaveV4ConfigEngine.AssetConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine IR call";
    require u.hub == hubH, "Pins the update to the snapshotted scene contracts";

    // The merge reads current data off the asset's own strategy, so pin that strategy to
    // the instance this rule reads back from.
    uint256 assetId = hubH.getAssetId(u.underlying);
    require hubH.getAssetConfig(assetId).irStrategy == irH, "Anchors the merge read to the snapshotted strategy";

    // Create a valid AssetConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.AssetConfigUpdate[] updates;
    require updates.length == 1 && updates[0].hub == u.hub
        && updates[0].underlying == u.underlying
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].liquidityFee == u.liquidityFee
        && updates[0].feeReceiver == u.feeReceiver
        && updates[0].irStrategy == u.irStrategy
        && updates[0].reinvestmentController == u.reinvestmentController
        && updates[0].irData.optimalUsageRatio == u.irData.optimalUsageRatio
        && updates[0].irData.baseDrawnRate == u.irData.baseDrawnRate
        && updates[0].irData.rateGrowthBeforeOptimal == u.irData.rateGrowthBeforeOptimal
        && updates[0].irData.rateGrowthAfterOptimal == u.irData.rateGrowthAfterOptimal;

    // Fetch the InterestRateData before the update
    IAssetInterestRateStrategy.InterestRateData before = irH.getInterestRateData(assetId);

    // Execute the update
    updateHubAssetIRs(e, updates);

    // Fetch the InterestRateData after the update
    IAssetInterestRateStrategy.InterestRateData after = irH.getInterestRateData(assetId);

    // Assert that every sentinel field kept its pre-call value
    assert u.irData.optimalUsageRatio == KEEP_CURRENT_UINT16()
        => after.optimalUsageRatio == before.optimalUsageRatio;
    assert u.irData.baseDrawnRate == KEEP_CURRENT_UINT32()
        => after.baseDrawnRate == before.baseDrawnRate;
    assert u.irData.rateGrowthBeforeOptimal == KEEP_CURRENT_UINT32()
        => after.rateGrowthBeforeOptimal == before.rateGrowthBeforeOptimal;
    assert u.irData.rateGrowthAfterOptimal == KEEP_CURRENT_UINT32()
        => after.rateGrowthAfterOptimal == before.rateGrowthAfterOptimal;
}

// Verify that the add cap does not move the draw cap
rule addCapDoesNotMoveDrawCap(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1 && updates[0].hub == u.hub
        && updates[0].spoke == u.spoke && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Fetch the SpokeConfig before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint40 drawBefore = hubH.getSpokeConfig(assetId, u.spoke).drawCap;

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that the draw cap was not touched
    assert u.drawCap == KEEP_CURRENT()
        => hubH.getSpokeConfig(assetId, u.spoke).drawCap == drawBefore;
}

// Verify that the draw cap does not move the add cap
rule drawCapDoesNotMoveAddCap(env e, IAaveV4ConfigEngine.SpokeConfigUpdate u) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";
   
    // Create a valid SpokeConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    require updates.length == 1 && updates[0].hub == u.hub
        && updates[0].spoke == u.spoke && updates[0].underlying == u.underlying
        && updates[0].addCap == u.addCap && updates[0].drawCap == u.drawCap
        && updates[0].hubConfigurator == u.hubConfigurator
        && updates[0].riskPremiumThreshold == u.riskPremiumThreshold
        && updates[0].active == u.active && updates[0].halted == u.halted;

    // Fetch the SpokeConfig before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint40 addBefore = hubH.getSpokeConfig(assetId, u.spoke).addCap;

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Assert that the add cap was not touched
    assert u.addCap == KEEP_CURRENT()
        => hubH.getSpokeConfig(assetId, u.spoke).addCap == addBefore;
}

// Verify that collateral factor changes does not move the max bonus
rule collateralFactorKeepsMaxBonus(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {
    // Create a valid DynamicReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].dynamicConfigKey == u.dynamicConfigKey
        && updates[0].collateralFactor == u.collateralFactor
        && updates[0].maxLiquidationBonus == u.maxLiquidationBonus
        && updates[0].liquidationFee == u.liquidationFee
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Fetch the DynamicReserveConfig before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);
    uint32 bonusBefore = spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Assert that the max liquidation bonus was not touched
    assert u.maxLiquidationBonus == KEEP_CURRENT()
        => spokeH.getDynamicReserveConfig(reserveId, key).maxLiquidationBonus == bonusBefore;
}

// Verify that max bonus changes does not move the collateral factor
rule maxBonusKeepsCollateralFactor(env e, IAaveV4ConfigEngine.DynamicReserveConfigUpdate u) {
    // Create a valid DynamicReserveConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].hub == u.hub && updates[0].underlying == u.underlying
        && updates[0].dynamicConfigKey == u.dynamicConfigKey
        && updates[0].collateralFactor == u.collateralFactor
        && updates[0].maxLiquidationBonus == u.maxLiquidationBonus
        && updates[0].liquidationFee == u.liquidationFee
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Fetch the DynamicReserveConfig before the update
    uint256 assetId = hubH.getAssetId(u.underlying);
    uint256 reserveId = spokeH.getReserveId(u.hub, assetId);
    uint32 key = require_uint32(u.dynamicConfigKey);
    uint16 factorBefore = spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor;

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Assert that the collateral factor was not touched
    assert u.collateralFactor == KEEP_CURRENT()
        => spokeH.getDynamicReserveConfig(reserveId, key).collateralFactor == factorBefore;
}

// Verify that a sentinel liquidation field is never written.
rule liqKeepsSentinelFields(env e, IAaveV4ConfigEngine.LiquidationConfigUpdate u) {
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

    // Create a valid LiquidationConfigUpdate array and constrain it to the input
    IAaveV4ConfigEngine.LiquidationConfigUpdate[] updates;
    require updates.length == 1 && updates[0].spoke == u.spoke
        && updates[0].targetHealthFactor == u.targetHealthFactor
        && updates[0].healthFactorForMaxBonus == u.healthFactorForMaxBonus
        && updates[0].liquidationBonusFactor == u.liquidationBonusFactor
        && updates[0].spokeConfigurator == u.spokeConfigurator;

    // Fetch the LiquidationConfig before the update
    ISpoke.LiquidationConfig before = spokeH.getLiquidationConfig();

    // Execute the update
    updateSpokeLiquidationConfigs(e, updates);

    // Fetch the LiquidationConfig after the update
    ISpoke.LiquidationConfig after = spokeH.getLiquidationConfig();

    // Assert that every sentinel field kept its pre-call value
    assert u.targetHealthFactor == KEEP_CURRENT()
        => after.targetHealthFactor == before.targetHealthFactor;
    assert u.healthFactorForMaxBonus == KEEP_CURRENT()
        => after.healthFactorForMaxBonus == before.healthFactorForMaxBonus;
    assert u.liquidationBonusFactor == KEEP_CURRENT()
        => after.liquidationBonusFactor == before.liquidationBonusFactor;
}