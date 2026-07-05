// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardAddDynamicReserveConfigsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  /// @dev liquidationFee is immutable across dynamic configs for the same reserve since it doesn't
  /// affect risk.
  function test_addDynamicReserveConfigs() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee; // must equal previous

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    uint32 nextKey = latestKey + 1;
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.AddDynamicReserveConfig(reserveId, nextKey, u.dynamicConfig);

    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, nextKey), u.dynamicConfig);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, nextKey);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_addDynamicReserveConfigs(int256 cfDelta, int256 mlbDelta) public {
    IRiskSteward.SpokeDynamicConfig memory dynBounds = steward.getConfig().spoke.dynamicAdd;
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );

    cfDelta = _boundDelta(cfDelta, dynBounds.collateralFactor.maxPercentChange);
    mlbDelta = _boundDelta(mlbDelta, dynBounds.maxLiquidationBonus.maxPercentChange);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = _applyDelta({
      current: ref.collateralFactor,
      delta: cfDelta,
      floor: 1 // avoid InvalidUpdateToZero
    }).toUint16();
    u.dynamicConfig.maxLiquidationBonus = _applyDelta({
      current: ref.maxLiquidationBonus,
      delta: mlbDelta,
      floor: PercentageMath.PERCENTAGE_FACTOR
    }).toUint32();
    u.dynamicConfig.liquidationFee = ref.liquidationFee;

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    uint32 nextKey = latestKey + 1;
    vm.expectEmit(address(MAIN_SPOKE));
    emit ISpoke.AddDynamicReserveConfig(reserveId, nextKey, u.dynamicConfig);

    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    assertEq(MAIN_SPOKE.getDynamicReserveConfig(reserveId, nextKey), u.dynamicConfig);
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, nextKey);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }

  function test_addDynamicReserveConfigs_revertsWith_ConfiguratorMismatch() public {
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.spokeConfigurator = ISpokeConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_revertsWith_UpdateNotInRange() public {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 5_01;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_liquidationFeeDiffers_revertsWith_ParamChangeNotAllowed()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus;
    u.dynamicConfig.liquidationFee = ref.liquidationFee + 1;

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_zeroCollateralFactor_revertsWith_InvalidUpdateToZero()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = 0;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_zeroMaxLiquidationBonus_revertsWith_InvalidUpdateToZero()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);

    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.maxLiquidationBonus = 0;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_whenSpokeRestricted_revertsWith_RestrictedAddress()
    public
  {
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IRiskSteward.RestrictedAddress.selector, address(MAIN_SPOKE))
    );
    steward.addDynamicReserveConfigs(_toArray(u));
  }

  function test_addDynamicReserveConfigs_secondAddTooSoon_revertsWith_DebounceNotRespected()
    public
  {
    (ISpoke.DynamicReserveConfig memory ref, ) = _dynamicReserveConfig(MAIN_SPOKE, HUB, ASSET);
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    uint256 minDelay = steward.getConfig().spoke.dynamicAdd.collateralFactor.minDelay;
    skip(minDelay - 1);

    IEngine.DynamicReserveConfigAddition memory u2 = _baseAddDynamic(); // same-value add vs new latest
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.addDynamicReserveConfigs(_toArray(u2));
  }

  function test_addDynamicReserveConfigs_secondAddAfterDelay_succeeds() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    uint256 minDelay = steward.getConfig().spoke.dynamicAdd.collateralFactor.minDelay;
    skip(minDelay + 1);

    IEngine.DynamicReserveConfigAddition memory u2 = _baseAddDynamic(); // same-value add vs new latest
    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u2));

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 2);
    assertEq(
      steward.getSpokeDynamicDebounce(address(MAIN_SPOKE), address(HUB), ASSET).collateralFactor,
      vm.getBlockTimestamp().toUint40()
    );
  }

  function test_addThenUpdateImmediately_revertsWith_DebounceNotRespected() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;
    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(_toArray(u));

    IEngine.DynamicReserveConfigUpdate memory up = _baseDynamicUpdate();
    up.dynamicConfigKey = latestKey + 1; // the freshly-created key
    up.collateralFactor = uint256(u.dynamicConfig.collateralFactor) + 10;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateDynamicReserveConfigs(_toArray(up));
  }

  /// @dev Two same-reserve additions in one batch are allowed (no dedup needed): the engine
  /// appends both as keys `N+1` and `N+2`, but only `N+2` is reachable by new positions, and the
  /// per-reserve debounce is stamped once. Documents the intentional non-dedup behavior.
  function test_addDynamicReserveConfigs_duplicateInBatch_succeedsAndStampsOnce() public {
    (ISpoke.DynamicReserveConfig memory ref, uint32 latestKey) = _dynamicReserveConfig(
      MAIN_SPOKE,
      HUB,
      ASSET
    );
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = ref.collateralFactor + 50;
    u.dynamicConfig.maxLiquidationBonus = ref.maxLiquidationBonus + 50;
    u.dynamicConfig.liquidationFee = ref.liquidationFee;

    IEngine.DynamicReserveConfigAddition[]
      memory additions = new IEngine.DynamicReserveConfigAddition[](2);
    additions[0] = u;
    additions[1] = u;

    vm.prank(RISK_COUNCIL);
    steward.addDynamicReserveConfigs(additions);

    uint256 reserveId = MAIN_SPOKE.getReserveId(address(HUB), HUB.getAssetId(ASSET));
    assertEq(MAIN_SPOKE.getReserve(reserveId).dynamicConfigKey, latestKey + 2);

    IRiskSteward.SpokeDynamicDebounce memory debounce = steward.getSpokeDynamicDebounce(
      address(MAIN_SPOKE),
      address(HUB),
      ASSET
    );
    assertEq(debounce.collateralFactor, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.maxLiquidationBonus, vm.getBlockTimestamp().toUint40());
  }
}
