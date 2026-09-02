/*
 * RiskSteward — Invariants: `_config` storage discipline.
 *
 * Property: a successful setConfig stores exactly its argument, and no other
 * method can change `_config`.
 */

methods {
    function getConfig() external returns (IRiskSteward.Config) envfree;
    function isAddressRestricted(address addr) external returns (bool) envfree;

    // See header: keep currentContract storage intact across external hops so R2
    // measures the real (unhavoced) `_config`.
    unresolved external in _._ => HAVOC_ECF;
}

// CVL cannot compare structs, so equality is spelled out. `Config` bottoms out
// in RiskParamConfig leaves, so only the leaf needs field-by-field work.
function paramEq(IRiskSteward.RiskParamConfig a, IRiskSteward.RiskParamConfig b) returns bool {
    return a.minDelay == b.minDelay
        && a.maxPercentChange == b.maxPercentChange
        && a.isChangeRelative == b.isChangeRelative;
}

// Compare two Config structs for equality
function configEq(IRiskSteward.Config a, IRiskSteward.Config b) returns bool {
    return a.hub.configurator == b.hub.configurator
        && paramEq(a.hub.rate.optimalUsageRatio, b.hub.rate.optimalUsageRatio)
        && paramEq(a.hub.rate.baseDrawnRate, b.hub.rate.baseDrawnRate)
        && paramEq(a.hub.rate.rateGrowthBeforeOptimal, b.hub.rate.rateGrowthBeforeOptimal)
        && paramEq(a.hub.rate.rateGrowthAfterOptimal, b.hub.rate.rateGrowthAfterOptimal)
        && paramEq(a.hub.cap.addCap, b.hub.cap.addCap)
        && paramEq(a.hub.cap.drawCap, b.hub.cap.drawCap)
        && a.spoke.configurator == b.spoke.configurator
        && paramEq(a.spoke.collateralRisk, b.spoke.collateralRisk)
        && paramEq(a.spoke.dynamicUpdate.collateralFactor, b.spoke.dynamicUpdate.collateralFactor)
        && paramEq(a.spoke.dynamicUpdate.maxLiquidationBonus, b.spoke.dynamicUpdate.maxLiquidationBonus)
        && paramEq(a.spoke.dynamicAdd.collateralFactor, b.spoke.dynamicAdd.collateralFactor)
        && paramEq(a.spoke.dynamicAdd.maxLiquidationBonus, b.spoke.dynamicAdd.maxLiquidationBonus)
        && paramEq(a.spoke.liquidation.targetHealthFactor, b.spoke.liquidation.targetHealthFactor)
        && paramEq(a.spoke.liquidation.healthFactorForMaxBonus, b.spoke.liquidation.healthFactorForMaxBonus)
        && paramEq(a.spoke.liquidation.liquidationBonusFactor, b.spoke.liquidation.liquidationBonusFactor)
        && paramEq(a.oracle.priceCapLst, b.oracle.priceCapLst)
        && paramEq(a.oracle.priceCapStable, b.oracle.priceCapStable)
        && paramEq(a.oracle.discountRatePendle, b.oracle.discountRatePendle);
}

// Establishment: a non-reverting setConfig (owner + all 17 polarity
// requires passed) leaves `_config` equal to the validated argument.
rule setConfigWritesArg(env e, IRiskSteward.Config cfg) {
    // Execute setConfig
    setConfig(e, cfg);

    // Assert that `_config` equals the validated argument
    assert configEq(getConfig(), cfg);
}

// Non-interference: every other method leaves `_config` byte-identical, i.e. setConfig is the sole writer.
rule configIntactExceptSetConfig(method f, env e)
    filtered { f -> f.selector != sig:setConfig(IRiskSteward.Config).selector }
{
    // Fetch `_config` before the call
    IRiskSteward.Config before = getConfig();
    calldataarg a;

    // Execute the call
    f(e, a);

    // Assert that `_config` was not touched
    assert configEq(getConfig(), before);
}

// Restriction map integrity: every other method leaves the restriction map intact
// i.e. setAddressRestricted is the sole writer.
rule restrictionMapIntactExceptSetter(method f, env e, address a)
    filtered { f -> f.selector != sig:setAddressRestricted(address,bool).selector }
{
    bool before = isAddressRestricted(a);
    calldataarg args;
    f(e, args);
    assert isAddressRestricted(a) == before;
}

// setConfig rejects any config with wrong per-field polarity.

definition polarityOk(IRiskSteward.Config c) returns bool =
    !c.hub.rate.optimalUsageRatio.isChangeRelative &&
    !c.hub.rate.baseDrawnRate.isChangeRelative &&
    !c.hub.rate.rateGrowthBeforeOptimal.isChangeRelative &&
    !c.hub.rate.rateGrowthAfterOptimal.isChangeRelative &&
     c.hub.cap.addCap.isChangeRelative &&
     c.hub.cap.drawCap.isChangeRelative &&
    !c.spoke.collateralRisk.isChangeRelative &&
    !c.spoke.dynamicUpdate.collateralFactor.isChangeRelative &&
    !c.spoke.dynamicUpdate.maxLiquidationBonus.isChangeRelative &&
    !c.spoke.dynamicAdd.collateralFactor.isChangeRelative &&
    !c.spoke.dynamicAdd.maxLiquidationBonus.isChangeRelative &&
     c.spoke.liquidation.targetHealthFactor.isChangeRelative &&
     c.spoke.liquidation.healthFactorForMaxBonus.isChangeRelative &&
    !c.spoke.liquidation.liquidationBonusFactor.isChangeRelative &&
     c.oracle.priceCapLst.isChangeRelative &&
     c.oracle.priceCapStable.isChangeRelative &&
    !c.oracle.discountRatePendle.isChangeRelative;
// R4 — G1: setConfig rejects any config with wrong per-field polarity.
// With R1 (storage == arg) and R2 (sole writer), this gives G1 for every
// reachable non-genesis state. Genesis is all-zero, so the six relative-mode
// fields are false there — that is G1's genesis disjunct, not a violation.
rule setConfigEnforcesPolarity(env e, IRiskSteward.Config cfg) {
    setConfig@withrevert(e, cfg);
    assert !polarityOk(cfg) => lastReverted;
}