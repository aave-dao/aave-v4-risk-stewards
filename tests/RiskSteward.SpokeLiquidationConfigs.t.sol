// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardSpokeLiquidationConfigsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  function test_updateSpokeLiquidationConfigs_allThree() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = (uint256(current.targetHealthFactor) * 103) / 100; // +3% relative
    u.healthFactorForMaxBonus = (uint256(current.healthFactorForMaxBonus) * 103) / 100;
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) + 1_00; // absolute

    ISpoke.LiquidationConfig memory expected = ISpoke.LiquidationConfig({
      targetHealthFactor: u.targetHealthFactor.toUint128(),
      healthFactorForMaxBonus: u.healthFactorForMaxBonus.toUint64(),
      liquidationBonusFactor: u.liquidationBonusFactor.toUint16()
    });
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateLiquidationConfig(expected);

    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getLiquidationConfig(), expected);

    IRiskSteward.SpokeLiquidationDebounce memory debounce = steward.getSpokeLiquidationDebounce(
      address(MAIN_SPOKE)
    );
    assertEq(debounce.targetHealthFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.healthFactorForMaxBonus, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.liquidationBonusFactor, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_updateSpokeLiquidationConfigs_allThree(
    int256 targetHealthFactorDeltaBps,
    int256 healthFactorForMaxBonusDeltaBps,
    int256 liquidationBonusFactorDelta
  ) public {
    IRiskSteward.SpokeLiquidationConfig memory liqBounds = steward.getConfig().spoke.liquidation;
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();

    targetHealthFactorDeltaBps = _boundDelta(
      targetHealthFactorDeltaBps,
      liqBounds.targetHealthFactor.maxPercentChange
    );
    healthFactorForMaxBonusDeltaBps = _boundDelta(
      healthFactorForMaxBonusDeltaBps,
      liqBounds.healthFactorForMaxBonus.maxPercentChange
    );
    liquidationBonusFactorDelta = _boundDelta(
      liquidationBonusFactorDelta,
      liqBounds.liquidationBonusFactor.maxPercentChange
    );

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = _applyRelativeDelta({
      current: current.targetHealthFactor,
      deltaBps: targetHealthFactorDeltaBps,
      floor: 1e18 // HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    });
    u.healthFactorForMaxBonus = _applyRelativeDelta({
      current: current.healthFactorForMaxBonus,
      deltaBps: healthFactorForMaxBonusDeltaBps,
      floor: 0,
      ceiling: 1e18 - 1 // strictly < HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    });
    u.liquidationBonusFactor = _applyDelta({
      current: current.liquidationBonusFactor,
      delta: liquidationBonusFactorDelta,
      floor: 1, // avoid InvalidUpdateToZero
      ceiling: 100_00 // PERCENTAGE_FACTOR (protocol max)
    });

    ISpoke.LiquidationConfig memory expected = ISpoke.LiquidationConfig({
      targetHealthFactor: u.targetHealthFactor.toUint128(),
      healthFactorForMaxBonus: u.healthFactorForMaxBonus.toUint64(),
      liquidationBonusFactor: u.liquidationBonusFactor.toUint16()
    });
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateLiquidationConfig(expected);

    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getLiquidationConfig(), expected);

    IRiskSteward.SpokeLiquidationDebounce memory debounce = steward.getSpokeLiquidationDebounce(
      address(MAIN_SPOKE)
    );
    assertEq(debounce.targetHealthFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.healthFactorForMaxBonus, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.liquidationBonusFactor, vm.getBlockTimestamp().toUint40());
  }

  function test_updateSpokeLiquidationConfigs_outOfRangeRelative_revertsWith_UpdateNotInRange()
    public
  {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = (uint256(current.targetHealthFactor) * 110) / 100; // +10% > 5% bound
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_outOfRangeAbsolute_revertsWith_UpdateNotInRange()
    public
  {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) + 5_01; // > 5_00 absolute
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_InvalidUpdateToZero() public {
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_SpokeIsRestricted() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    vm.prank(OWNER);
    steward.setSpokeRestricted(address(MAIN_SPOKE), true);
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = current.targetHealthFactor;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.SpokeIsRestricted.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_updateSpokeLiquidationConfigs_partialUpdate_onlyBumpsTouched() public {
    ISpoke.LiquidationConfig memory current = MAIN_SPOKE.getLiquidationConfig();
    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) + 1_00;
    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    IRiskSteward.SpokeLiquidationDebounce memory debounce = steward.getSpokeLiquidationDebounce(
      address(MAIN_SPOKE)
    );
    assertEq(debounce.liquidationBonusFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.targetHealthFactor, 0);
    assertEq(debounce.healthFactorForMaxBonus, 0);
  }

  function test_updateSpokeLiquidationConfigs_onLidoSpoke() public {
    ISpoke.LiquidationConfig memory current = LIDO_SPOKE.getLiquidationConfig();

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.spoke = address(LIDO_SPOKE);
    u.liquidationBonusFactor = uint256(current.liquidationBonusFactor) - 1_00;

    vm.prank(RISK_COUNCIL);
    steward.updateSpokeLiquidationConfigs(_toArray(u));

    assertEq(
      steward.getSpokeLiquidationDebounce(address(LIDO_SPOKE)).liquidationBonusFactor,
      vm.getBlockTimestamp().toUint40()
    );
  }
}
