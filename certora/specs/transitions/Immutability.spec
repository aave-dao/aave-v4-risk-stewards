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

    // Dropping these only adds executions: they gate or compute, never write the fields
    // asserted below, so removing them cannot hide a forbidden write. `_validateParamUpdate`
    // is the debounce/bounds gate — those live in DebounceStamping.spec and ProtocolEffects.spec.
    function RiskSteward._validateParamUpdate(IRiskSteward.ParamUpdateValidationInput memory) internal => NONDET;
    function AssetLogic.getDrawnIndex(IHub.Asset storage) internal returns (uint256) => NONDET;
    function AssetLogic.getUnrealizedFees(IHub.Asset storage, uint256) internal returns (uint256) => NONDET;
    function Hub._mintFeeShares(IHub.Asset storage, uint256) internal returns (uint256) => NONDET;

    // priceSource lives in the out-of-scene oracle, so we candetect attempted writes.
    function _.setReserveSource(uint256 reserveId, address source)
        external => markPriceSource() expect void;

    // `=> anyIRData()` rather than `=> NONDET`: CVL rejects NONDET on a reference return type. 
    function RiskSteward._getCurrentIRData(address, address) internal returns (IAssetInterestRateStrategy.InterestRateData memory) 
        => anyIRData();
}

// Batch bound for the key-isolation helpers for prover performances.
definition HUB_MAX_BATCH() returns uint256 = 3;

function anyIRData() returns IAssetInterestRateStrategy.InterestRateData {
    IAssetInterestRateStrategy.InterestRateData d;
    return d;
}

// ---------------------------------------------------------------------------
// updateHubAssetIRs path: liquidityFee / feeReceiver / irStrategy / reinvestmentController
// ---------------------------------------------------------------------------

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

// Make sure price source is not touched
rule reserveKeepsPriceSource(env e) {
    // Require the caller to be the RiskCouncil (Prover Performances Helper)
    require e.msg.sender == RISK_COUNCIL();
    
    // Pins the configurator RiskSteward will itself demand of every element.
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

    // Create a valid ReserveConfigUpdate array
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    require updates.length <= 1,"Limit batch updates elements to 1 for prover performances";
    
    require !priceSourceTouched,"Require satisfying fresh start";

    // Execute the update
    updateReserveConfigs(e, updates);

    // Assert that the price source was not touched
    assert !priceSourceTouched;
}

// Make sure immutable parameters are not touched
rule reserveKeepsFlags(env e, uint256 reserveId) {
    // Require the caller to be the RiskCouncil (Prover Performances Helper)
    require e.msg.sender == RISK_COUNCIL();

    // Pins the configurator RiskSteward will itself demand of every element.
    require getConfig().spoke.configurator == spokeConfig, "Speeds up SpokeEngine dispatch; not needed for soundness";

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

// ---------------------------------------------------------------------------
// (i) FIELD isolation — same key, sibling field untouched
// ---------------------------------------------------------------------------

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

// ---------------------------------------------------------------------------
// (ii) KEY isolation — distinct cell unchanged
// ---------------------------------------------------------------------------

// No element of the batch names the (otherAssetId, otherSpoke) cell.
function capsBatchAvoids(IAaveV4ConfigEngine.SpokeConfigUpdate[] updates,uint256 otherAssetId, address otherSpoke) 
{
    require updates.length <= HUB_MAX_BATCH();
    require hubH.getAssetId(updates[0].underlying) != otherAssetId || updates[0].spoke != otherSpoke;
    require updates.length < 2 || hubH.getAssetId(updates[1].underlying) != otherAssetId || updates[1].spoke != otherSpoke;
    require updates.length < 3 || hubH.getAssetId(updates[2].underlying) != otherAssetId || updates[2].spoke != otherSpoke;
}

// No element of the batch names the otherReserveId cell.
function reserveBatchAvoids(IAaveV4ConfigEngine.ReserveConfigUpdate[] updates,uint256 otherReserveId) 
{
    require updates.length <= HUB_MAX_BATCH();
    require spokeH.getReserveId(updates[0].hub, hubH.getAssetId(updates[0].underlying)) != otherReserveId;
    require updates.length < 2 || spokeH.getReserveId(updates[1].hub, hubH.getAssetId(updates[1].underlying)) != otherReserveId;
    require updates.length < 3 || spokeH.getReserveId(updates[2].hub, hubH.getAssetId(updates[2].underlying)) != otherReserveId;
}

// No element of the batch names the (otherReserveId, otherKey) cell.
function dynBatchAvoids(IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates,uint256 otherReserveId, uint32 otherKey) 
{
    require updates.length <= HUB_MAX_BATCH();
    require spokeH.getReserveId(updates[0].hub, hubH.getAssetId(updates[0].underlying)) != otherReserveId || to_mathint(updates[0].dynamicConfigKey) != to_mathint(otherKey);
    require updates.length < 2 || spokeH.getReserveId(updates[1].hub, hubH.getAssetId(updates[1].underlying)) != otherReserveId || to_mathint(updates[1].dynamicConfigKey) != to_mathint(otherKey);
    require updates.length < 3 || spokeH.getReserveId(updates[2].hub, hubH.getAssetId(updates[2].underlying)) != otherReserveId || to_mathint(updates[2].dynamicConfigKey) != to_mathint(otherKey);
}

// Verify that the add cap and draw cap were not touched
rule hubCapsKeyIsolation(env e, uint256 otherAssetId, address otherSpoke) {
    require getConfig().hub.configurator == hubConfig, "Prevents HAVOC_ALL on the unresolved HubEngine caps call";

    // Create a valid SpokeConfigUpdate batch that avoids the snapshotted cell
    IAaveV4ConfigEngine.SpokeConfigUpdate[] updates;
    capsBatchAvoids(updates, otherAssetId, otherSpoke);

    // Fetch the SpokeConfig of other asset id and other spoke before the update
    IHub.SpokeConfig before = hubH.getSpokeConfig(otherAssetId, otherSpoke);

    // Execute the update
    updateHubSpokeCaps(e, updates);

    // Fetch the SpokeConfig of other asset id and other spoke after the update
    IHub.SpokeConfig after = hubH.getSpokeConfig(otherAssetId, otherSpoke);

    // Assert that the add cap and draw cap were not touched
    assert after.addCap == before.addCap && after.drawCap == before.drawCap;
}

// Verify that the collateral risk was not touched
rule reserveConfigKeyIsolation(env e, uint256 otherReserveId) {
    // Create a valid ReserveConfigUpdate batch that avoids the snapshotted cell
    IAaveV4ConfigEngine.ReserveConfigUpdate[] updates;
    reserveBatchAvoids(updates, otherReserveId);

    // Fetch the ReserveConfig of other reserve id before the update
    ISpoke.ReserveConfig before = spokeH.getReserveConfig(otherReserveId);

    // Execute the update
    updateReserveConfigs(e, updates);

    // Fetch the ReserveConfig of other reserve id after the update
    ISpoke.ReserveConfig after = spokeH.getReserveConfig(otherReserveId);

    // Assert that the collateral risk was not touched
    assert after.collateralRisk == before.collateralRisk;
}

// Verify that the collateral factor and max liquidation bonus were not touched
rule dynamicConfigKeyIsolation(env e, uint256 otherReserveId, uint32 otherKey) {
    // Create a valid DynamicReserveConfigUpdate batch that avoids the snapshotted cell
    IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] updates;
    dynBatchAvoids(updates, otherReserveId, otherKey);

    // Fetch the DynamicReserveConfig of other reserve id and other key before the update
    ISpoke.DynamicReserveConfig before = spokeH.getDynamicReserveConfig(otherReserveId, otherKey);

    // Execute the update
    updateDynamicReserveConfigs(e, updates);

    // Fetch the DynamicReserveConfig of other reserve id and other key after the update
    ISpoke.DynamicReserveConfig after = spokeH.getDynamicReserveConfig(otherReserveId, otherKey);

    // Assert that the collateral factor and max liquidation bonus were not touched
    assert after.collateralFactor == before.collateralFactor
        && after.maxLiquidationBonus == before.maxLiquidationBonus;
}
