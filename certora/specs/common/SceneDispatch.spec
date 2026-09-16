/*
 * Shared write-path resolution for the full-scene RiskSteward transition proofs.
 * It includes both allowlisted and forbidden setters because a forbidden setter
 * left havoced would wipe the storage snapshotted by the immutability rules.
 *
 * SOUNDNESS
 * DISPATCHER(true) is optimistic: it assumes the callee is one of the scene contracts.
 *
 * `default HAVOC_ALL` is deliberate and must NOT be relaxed to NONDET: a write path
 * we failed to enumerate has to fail loudly instead of quietly doing nothing.
 */

methods {
    function AuthorityUtils.canCallWithDelay(address authority, address caller, address target, bytes4 selector) internal returns (bool, uint32) => alwaysAllowed();

    // ---- reads (steward's own validation reads, and the configurators' RMW reads) ----
    function _.getAssetId(address) external => DISPATCHER(true);
    function _.getAssetConfig(uint256) external => DISPATCHER(true);
    function _.getSpokeConfig(uint256, address) external => DISPATCHER(true);
    function _.getInterestRateData(uint256) external => DISPATCHER(true);
    function _.getReserveId(address, uint256) external => DISPATCHER(true);
    function _.getReserve(uint256) external => DISPATCHER(true);
    function _.getReserveConfig(uint256) external => DISPATCHER(true);
    function _.getDynamicReserveConfig(uint256, uint32) external => DISPATCHER(true);
    function _.getLiquidationConfig() external => DISPATCHER(true);

    // HubEngine -> HubConfigurator ----
    // Allowlisted fields.
    function _.updateSpokeCaps(address, uint256, address, uint256, uint256) external => DISPATCHER(true);
    function _.updateSpokeAddCap(address, uint256, address, uint256) external => DISPATCHER(true);
    function _.updateSpokeDrawCap(address, uint256, address, uint256) external => DISPATCHER(true);
    function _.updateInterestRateData(address, uint256, bytes) external => DISPATCHER(true);

    // Forbidden fields: needed by P2b. If these stayed havoc'd they would wipe the
    // Hub storage the snapshot rules read back.
    function _.updateLiquidityFee(address, uint256, uint256) external => DISPATCHER(true);
    function _.updateFeeReceiver(address, uint256, address) external => DISPATCHER(true);
    function _.updateFeeConfig(address, uint256, uint256, address) external => DISPATCHER(true);
    function _.updateInterestRateStrategy(address, uint256, address, bytes) external => DISPATCHER(true);
    function _.updateReinvestmentController(address, uint256, address) external => DISPATCHER(true);
    function _.updateSpokeRiskPremiumThreshold(address, uint256, address, uint256) external => DISPATCHER(true);
    function _.updateSpokeActive(address, uint256, address, bool) external => DISPATCHER(true);
    function _.updateSpokeHalted(address, uint256, address, bool) external => DISPATCHER(true);

    // ---- hop 1: SpokeEngine -> SpokeConfigurator ----
    function _.updateCollateralRisk(address, uint256, uint256) external => DISPATCHER(true);
    function _.updateDynamicReserveConfig(address, uint256, uint32, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.addDynamicReserveConfig(address, uint256, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.updateLiquidationTargetHealthFactor(address, uint256) external => DISPATCHER(true);
    function _.updateHealthFactorForMaxBonus(address, uint256) external => DISPATCHER(true);
    function _.updateLiquidationBonusFactor(address, uint256) external => DISPATCHER(true);
    function _.updateLiquidationConfig(address, ISpoke.LiquidationConfig) external => DISPATCHER(true);
    // Forbidden fields: needed by P2c.
    function _.updateReservePriceSource(address, uint256, address) external => DISPATCHER(true);
    function _.updatePaused(address, uint256, bool) external => DISPATCHER(true);
    function _.updateFrozen(address, uint256, bool) external => DISPATCHER(true);
    function _.updateBorrowable(address, uint256, bool) external => DISPATCHER(true);
    function _.updateReceiveSharesEnabled(address, uint256, bool) external => DISPATCHER(true);

    // ---- hop 2: configurator -> Hub / Spoke storage ----
    // Note the arity split on the shared names: the forms taking a leading `address`
    // are the configurator entrypoints above; these shorter forms are the instances.
    function _.updateSpokeConfig(uint256, address, IHub.SpokeConfig) external => DISPATCHER(true);
    function _.updateAssetConfig(uint256, IHub.AssetConfig, bytes) external => DISPATCHER(true);
    function _.updateReserveConfig(uint256, ISpoke.ReserveConfig) external => DISPATCHER(true);
    function _.updateDynamicReserveConfig(uint256, uint32, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig) external => DISPATCHER(true);
    function _.updateLiquidationConfig(ISpoke.LiquidationConfig) external => DISPATCHER(true);
    function _.updateReservePriceSource(uint256, address) external => DISPATCHER(true);

    // Two hops share this signature — HubConfigurator -> Hub, then Hub -> strategy
    // One declaration covers both; DISPATCHER case-splits over the two scene contracts
    // implementing it and the receiver address picks the branch.
    function _.setInterestRateData(uint256, bytes) external => DISPATCHER(true);

    // Hub.setInterestRateData also runs accrue()/updateDrawnRate(), which call into the
    // strategy's nonlinear ray math. That math never touches the fields these rules
    // assert on, so NONDET removes a large nonlinear term from the VC without weakening
    // the property.
    function _.calculateInterestRate(uint256, uint256, uint256, uint256, uint256) external => NONDET;

    // Sites where the selector itself is unresolved, so none of the sighash-keyed
    // summaries above can bind. See failure mode (2) in the header.
    unresolved external in _._ => DISPATCH [
        HubConfiguratorHarness.updateSpokeCaps(address, uint256, address, uint256, uint256),
        HubConfiguratorHarness.updateSpokeAddCap(address, uint256, address, uint256),
        HubConfiguratorHarness.updateSpokeDrawCap(address, uint256, address, uint256),
        HubConfiguratorHarness.updateInterestRateData(address, uint256, bytes),
        HubConfiguratorHarness.updateLiquidityFee(address, uint256, uint256),
        HubConfiguratorHarness.updateFeeReceiver(address, uint256, address),
        HubConfiguratorHarness.updateFeeConfig(address, uint256, uint256, address),
        HubConfiguratorHarness.updateInterestRateStrategy(address, uint256, address, bytes),
        HubConfiguratorHarness.updateReinvestmentController(address, uint256, address),
        HubConfiguratorHarness.updateSpokeRiskPremiumThreshold(address, uint256, address, uint256),
        HubConfiguratorHarness.updateSpokeActive(address, uint256, address, bool),
        HubConfiguratorHarness.updateSpokeHalted(address, uint256, address, bool),
        HubHarness.updateSpokeConfig(uint256, address, IHub.SpokeConfig),
        HubHarness.updateAssetConfig(uint256, IHub.AssetConfig, bytes),
        HubHarness.setInterestRateData(uint256, bytes),
        AssetInterestRateStrategyHarness.setInterestRateData(uint256, bytes),
        SpokeConfiguratorHarness.updateCollateralRisk(address, uint256, uint256),
        SpokeConfiguratorHarness.updateDynamicReserveConfig(address, uint256, uint32, ISpoke.DynamicReserveConfig),
        SpokeConfiguratorHarness.addDynamicReserveConfig(address, uint256, ISpoke.DynamicReserveConfig),
        SpokeConfiguratorHarness.updateLiquidationTargetHealthFactor(address, uint256),
        SpokeConfiguratorHarness.updateHealthFactorForMaxBonus(address, uint256),
        SpokeConfiguratorHarness.updateLiquidationBonusFactor(address, uint256),
        SpokeConfiguratorHarness.updateLiquidationConfig(address, ISpoke.LiquidationConfig),
        SpokeConfiguratorHarness.updateReservePriceSource(address, uint256, address),
        SpokeConfiguratorHarness.updatePaused(address, uint256, bool),
        SpokeConfiguratorHarness.updateFrozen(address, uint256, bool),
        SpokeConfiguratorHarness.updateBorrowable(address, uint256, bool),
        SpokeConfiguratorHarness.updateReceiveSharesEnabled(address, uint256, bool),
        SpokeHarness.updateReserveConfig(uint256, ISpoke.ReserveConfig),
        SpokeHarness.updateDynamicReserveConfig(uint256, uint32, ISpoke.DynamicReserveConfig),
        SpokeHarness.addDynamicReserveConfig(uint256, ISpoke.DynamicReserveConfig),
        SpokeHarness.updateLiquidationConfig(ISpoke.LiquidationConfig),
        SpokeHarness.updateReservePriceSource(uint256, address)
    ] default HAVOC_ALL;
}

function alwaysAllowed() returns (bool, uint32) {
    return (true, 0);
}

// EngineFlags.KEEP_CURRENT = type(uint256).max - 652.
definition KEEP_CURRENT() returns uint256 = 0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffd73;

// EngineFlags.KEEP_CURRENT_ADDRESS = address(type(uint160).max).
definition KEEP_CURRENT_ADDRESS() returns address = 0xffffffffffffffffffffffffffffffffffffffff;
