// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardDynamicReserveConfigsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  function test_updateDynamicReserveConfigs() public {
    (ISpoke.DynamicReserveConfig memory current, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = current.collateralFactor + 50;
    u.maxLiquidationBonus = current.maxLiquidationBonus + 50;

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    ISpoke.DynamicReserveConfig memory expected = ISpoke.DynamicReserveConfig({
      collateralFactor: u.collateralFactor.toUint16(),
      maxLiquidationBonus: u.maxLiquidationBonus.toUint32(),
      liquidationFee: current.liquidationFee
    });
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateDynamicReserveConfig(reserveId, latestKey, expected);

    vm.prank(RISK_COUNCIL);
    steward.updateDynamicReserveConfigs(_toArray(u));

    (ISpoke.DynamicReserveConfig memory updated, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    assertEq(updated, expected);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_updateDynamicReserveConfigs(int256 cfDelta, int256 mlbDelta) public {
    IRiskSteward.SpokeDynamicConfig memory dynBounds = steward
      .getSpokeConfig(address(MAIN_SPOKE))
      .dynamicUpdate;
    (ISpoke.DynamicReserveConfig memory current, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    cfDelta = _boundDelta(cfDelta, dynBounds.collateralFactor.maxPercentChange);
    mlbDelta = _boundDelta(mlbDelta, dynBounds.maxLiquidationBonus.maxPercentChange);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = _applyDelta({
      current: current.collateralFactor,
      delta: cfDelta,
      floor: 1 // avoid InvalidUpdateToZero
    });
    u.maxLiquidationBonus = _applyDelta({
      current: current.maxLiquidationBonus,
      delta: mlbDelta,
      floor: PercentageMath.PERCENTAGE_FACTOR
    });

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    ISpoke.DynamicReserveConfig memory expected = ISpoke.DynamicReserveConfig({
      collateralFactor: u.collateralFactor.toUint16(),
      maxLiquidationBonus: u.maxLiquidationBonus.toUint32(),
      liquidationFee: current.liquidationFee
    });
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.UpdateDynamicReserveConfig(reserveId, latestKey, expected);

    vm.prank(RISK_COUNCIL);
    steward.updateDynamicReserveConfigs(_toArray(u));

    (ISpoke.DynamicReserveConfig memory updated, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    assertEq(updated, expected);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_updateDynamicReserveConfigs_revertsWith_UpdateNotInRange() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = uint256(current.collateralFactor) + 51;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_revertsWith_DebounceNotRespected() public {
    (ISpoke.DynamicReserveConfig memory current, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = uint256(current.collateralFactor) + 50;
    vm.prank(RISK_COUNCIL);
    steward.updateDynamicReserveConfigs(_toArray(u));

    IEngine.DynamicReserveConfigUpdate memory u2 = _baseDynamicUpdate();
    u2.collateralFactor = uint256(current.collateralFactor) + 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateDynamicReserveConfigs(_toArray(u2));
  }

  function test_updateDynamicReserveConfigs_liquidationFeeChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.liquidationFee = 5_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_zeroCollateralFactor_revertsWith_InvalidUpdateToZero()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.collateralFactor = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }

  function test_updateDynamicReserveConfigs_zeroMaxLiquidationBonus_revertsWith_InvalidUpdateToZero()
    public
  {
    IEngine.DynamicReserveConfigUpdate memory u = _baseDynamicUpdate();
    u.maxLiquidationBonus = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateDynamicReserveConfigs(_toArray(u));
  }
}
