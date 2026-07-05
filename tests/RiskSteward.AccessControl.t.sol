// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardAccessControlTest is RiskStewardTestBase {
  function test_updateHubAssetIRs_revertsWith_InvalidCaller() public {
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateHubAssetIRs(_toArray(_baseIRUpdate()));
  }

  function test_updateHubSpokeCaps_revertsWith_InvalidCaller() public {
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateHubSpokeCaps(_toArray(_baseSpokeCapsUpdate()));
  }

  function test_updateReserveConfigs_revertsWith_InvalidCaller() public {
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateReserveConfigs(_toArray(_baseReserveUpdate()));
  }

  function test_updateDynamicReserveConfigs_revertsWith_InvalidCaller() public {
    IEngine.DynamicReserveConfigUpdate[] memory updates = _toArray(_baseDynamicUpdate());
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateDynamicReserveConfigs(updates);
  }

  function test_addDynamicReserveConfigs_revertsWith_InvalidCaller() public {
    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(_baseAddDynamic());
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.addDynamicReserveConfigs(additions);
  }

  function test_updateSpokeLiquidationConfigs_revertsWith_InvalidCaller() public {
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(_baseLiquidationUpdate()));
  }

  function test_setConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setConfig(_defaultConfig());
  }

  function test_setAddressRestricted_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setAddressRestricted(address(HUB), true);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenIRMarkedRelative() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.hub.rate.baseDrawnRate.isChangeRelative = true;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenCapMarkedAbsolute() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.hub.cap.addCap.isChangeRelative = false;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenCollateralRiskRelative() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.spoke.collateralRisk.isChangeRelative = true;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenDynamicMarkedRelative() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.spoke.dynamicUpdate.collateralFactor.isChangeRelative = true;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenLiquidationBonusFactorRelative()
    public
  {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.spoke.liquidation.liquidationBonusFactor.isChangeRelative = true;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_setConfig_revertsWith_InvalidParamConfig_whenPriceCapLstAbsolute() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.oracle.priceCapLst.isChangeRelative = false;
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setConfig(cfg);
  }

  function test_getConfig_returnsStored() public view {
    IRiskSteward.Config memory got = steward.getConfig();
    assertEq(address(got.hub.configurator), address(HUB_CONFIGURATOR));
    assertEq(address(got.spoke.configurator), address(SPOKE_CONFIGURATOR));
    assertEq(got.hub.rate.optimalUsageRatio.minDelay, 3 days);
    assertEq(got.hub.rate.optimalUsageRatio.maxPercentChange, 3_00);
    assertEq(got.spoke.collateralRisk.minDelay, 3 days);
  }

  function test_restrictionToggles() public {
    address[4] memory targets = [address(HUB), address(MAIN_SPOKE), ASSET, makeAddr('ORACLE')];
    for (uint256 i; i < targets.length; ++i) {
      assertFalse(steward.isAddressRestricted(targets[i]));

      vm.prank(OWNER);
      vm.expectEmit(address(steward));
      emit IRiskSteward.AddressRestricted(targets[i], true);
      steward.setAddressRestricted(targets[i], true);
      assertTrue(steward.isAddressRestricted(targets[i]));

      vm.prank(OWNER);
      steward.setAddressRestricted(targets[i], false);
      assertFalse(steward.isAddressRestricted(targets[i]));
    }
  }
}
