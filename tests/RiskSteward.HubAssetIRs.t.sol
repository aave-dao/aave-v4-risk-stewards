// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardHubAssetIRsTest is RiskStewardTestBase {
  using SafeCast for *;

  function test_updateHubAssetIRs() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;
    u.irData.baseDrawnRate = current.baseDrawnRate + 1_00;
    u.irData.rateGrowthBeforeOptimal = current.rateGrowthBeforeOptimal + 1_00;
    u.irData.rateGrowthAfterOptimal = current.rateGrowthAfterOptimal + 1_00;

    uint256 assetId = HUB.getAssetId(ASSET);
    vm.expectEmit(HUB.getAssetConfig(assetId).irStrategy);
    emit IAssetInterestRateStrategy.UpdateInterestRateData(
      address(HUB),
      assetId,
      u.irData.optimalUsageRatio,
      u.irData.baseDrawnRate,
      u.irData.rateGrowthBeforeOptimal,
      u.irData.rateGrowthAfterOptimal
    );

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    assertEq(_interestRateData(HUB, ASSET), u.irData);

    IRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.baseDrawnRate, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthBeforeOptimal, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthAfterOptimal, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_updateHubAssetIRs(
    int256 optUsageDelta,
    int256 baseDrawnDelta,
    int256 rateGrowthBeforeDelta,
    int256 rateGrowthAfterDelta
  ) public {
    IRiskSteward.HubRateConfig memory rateBounds = steward.getConfig().hub.rate;
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    optUsageDelta = _boundDelta(optUsageDelta, rateBounds.optimalUsageRatio.maxPercentChange);
    baseDrawnDelta = _boundDelta(baseDrawnDelta, rateBounds.baseDrawnRate.maxPercentChange);
    rateGrowthBeforeDelta = _boundDelta(
      rateGrowthBeforeDelta,
      rateBounds.rateGrowthBeforeOptimal.maxPercentChange
    );
    rateGrowthAfterDelta = _boundDelta(
      rateGrowthAfterDelta,
      rateBounds.rateGrowthAfterOptimal.maxPercentChange
    );

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _applyDelta({
      current: current.optimalUsageRatio,
      delta: optUsageDelta,
      floor: 1_00, // MIN_OPTIMAL_RATIO
      ceiling: 99_00 // MAX_OPTIMAL_RATIO
    }).toUint16();
    u.irData.baseDrawnRate = _applyDelta({
      current: current.baseDrawnRate,
      delta: baseDrawnDelta,
      floor: 0
    }).toUint32();
    u.irData.rateGrowthBeforeOptimal = _applyDelta({
      current: current.rateGrowthBeforeOptimal,
      delta: rateGrowthBeforeDelta,
      floor: 0
    }).toUint32();
    u.irData.rateGrowthAfterOptimal = _applyDelta({
      current: current.rateGrowthAfterOptimal,
      delta: rateGrowthAfterDelta,
      floor: 0
    }).toUint32();

    uint256 assetId = HUB.getAssetId(ASSET);
    address irStrategy = HUB.getAssetConfig(assetId).irStrategy;
    vm.expectEmit(irStrategy);
    emit IAssetInterestRateStrategy.UpdateInterestRateData(
      address(HUB),
      assetId,
      u.irData.optimalUsageRatio,
      u.irData.baseDrawnRate,
      u.irData.rateGrowthBeforeOptimal,
      u.irData.rateGrowthAfterOptimal
    );

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    assertEq(_interestRateData(HUB, ASSET), u.irData);

    IRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.baseDrawnRate, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthBeforeOptimal, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.rateGrowthAfterOptimal, vm.getBlockTimestamp().toUint40());
  }

  function test_updateHubAssetIRs_keepCurrent_doesNotBumpTimelock() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate(); // all KEEP_CURRENT
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, 0);
    assertEq(debounce.baseDrawnRate, 0);
    assertEq(debounce.rateGrowthBeforeOptimal, 0);
    assertEq(debounce.rateGrowthAfterOptimal, 0);
  }

  function test_updateHubAssetIRs_partialUpdate_onlyBumpsTouched() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IRiskSteward.HubAssetDebounce memory debounce = steward.getHubAssetDebounce(
      address(HUB),
      ASSET
    );
    assertEq(debounce.optimalUsageRatio, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.baseDrawnRate, 0);
    assertEq(debounce.rateGrowthBeforeOptimal, 0);
    assertEq(debounce.rateGrowthAfterOptimal, 0);
  }

  function test_updateHubAssetIRs_sameValueUpdate_succeeds_bumpsTimelock() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio; // same value

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateHubAssetIRs_revertsWith_DebounceNotRespected() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    // Try again same block.
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = current.optimalUsageRatio + 1_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateHubAssetIRs(_toArray(u2));
  }

  function test_updateHubAssetIRs_batchSameParam_lastEntryWins() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u1 = _baseIRUpdate();
    u1.irData.optimalUsageRatio = current.optimalUsageRatio + 50; // both within 3_00 bound
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = current.optimalUsageRatio + 100;

    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](2);
    updates[0] = u1;
    updates[1] = u2;

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(updates);

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
    // u2's value is the final on-chain value.
    assertEq(_interestRateData(HUB, ASSET).optimalUsageRatio, u2.irData.optimalUsageRatio);

    IEngine.AssetConfigUpdate memory u3 = _baseIRUpdate();
    u3.irData.optimalUsageRatio = current.optimalUsageRatio + 110;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateHubAssetIRs(_toArray(u3));
  }

  function test_updateHubAssetIRs_overUpperBound_revertsWith_UpdateNotInRange() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    IRiskSteward.HubConfig memory hubConfig = steward.getConfig().hub;
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio =
      current.optimalUsageRatio +
      hubConfig.rate.optimalUsageRatio.maxPercentChange.toUint16() +
      1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_underLowerBound_revertsWith_UpdateNotInRange() public {
    IAssetInterestRateStrategy.InterestRateData memory current = _interestRateData(HUB, ASSET);
    IRiskSteward.HubConfig memory hubConfig = steward.getConfig().hub;
    uint16 maxPercentageChange = hubConfig.rate.optimalUsageRatio.maxPercentChange.toUint16();
    vm.assume(current.optimalUsageRatio >= maxPercentageChange + 2); // need room to subtract

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = current.optimalUsageRatio - maxPercentageChange - 1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_revertsWith_NoZeroUpdates() public {
    IEngine.AssetConfigUpdate[] memory updates = new IEngine.AssetConfigUpdate[](0);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.NoZeroUpdates.selector);
    steward.updateHubAssetIRs(updates);
  }

  function test_updateHubAssetIRs_zeroIsAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.baseDrawnRate = 0;

    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).baseDrawnRate,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_updateHubAssetIRs_revertsWith_ConfiguratorMismatch() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.hubConfigurator = IHubConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_revertsWith_HubIsRestricted() public {
    vm.prank(OWNER);
    steward.setHubRestricted(address(HUB), true);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _interestRateData(HUB, ASSET).optimalUsageRatio + 1_00;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.HubIsRestricted.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_irStrategyChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irStrategy = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_feeReceiverChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.feeReceiver = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_reinvestmentControllerChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.reinvestmentController = address(0xdead);

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_liquidityFeeChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.liquidityFee = 9_99;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_updateHubAssetIRs_afterDebounce_succeeds() public {
    IAssetInterestRateStrategy.InterestRateData memory before = _interestRateData(HUB, ASSET);

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = before.optimalUsageRatio + 1_00;
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u));

    IAssetInterestRateStrategy.InterestRateData memory afterFirst = _interestRateData(HUB, ASSET);

    skip(3 days + 1);
    IEngine.AssetConfigUpdate memory u2 = _baseIRUpdate();
    u2.irData.optimalUsageRatio = afterFirst.optimalUsageRatio - 50;
    vm.prank(RISK_COUNCIL);
    steward.updateHubAssetIRs(_toArray(u2));

    assertEq(
      steward.getHubAssetDebounce(address(HUB), ASSET).optimalUsageRatio,
      vm.getBlockTimestamp().toUint40()
    );
    assertEq(_interestRateData(HUB, ASSET).optimalUsageRatio, u2.irData.optimalUsageRatio);
  }
}
