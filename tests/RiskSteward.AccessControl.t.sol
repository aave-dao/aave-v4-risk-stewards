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

  function test_setHubConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setHubConfig(address(HUB), _defaultHubConfig());
  }

  function test_setSpokeConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setSpokeConfig(address(MAIN_SPOKE), _defaultSpokeConfig());
  }

  function test_removeHubConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.removeHubConfig(address(HUB));
  }

  function test_removeSpokeConfig_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.removeSpokeConfig(address(MAIN_SPOKE));
  }

  function test_setHubRestricted_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setHubRestricted(address(HUB), true);
  }

  function test_setSpokeRestricted_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setSpokeRestricted(address(MAIN_SPOKE), true);
  }

  function test_setSpokeHubRestricted_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setSpokeHubRestricted(address(MAIN_SPOKE), address(HUB), true);
  }

  function test_setReserveRestricted_revertsWith_OwnableUnauthorizedAccount() public {
    vm.expectRevert(
      abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this))
    );
    steward.setReserveRestricted(address(MAIN_SPOKE), address(HUB), ASSET, true);
  }

  function test_setHubConfig_revertsWith_InvalidParamConfig_whenIRMarkedRelative() public {
    IRiskSteward.HubConfig memory cfg = _defaultHubConfig();
    cfg.rate.baseDrawnRate.isChangeRelative = true; // IR must be absolute
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setHubConfig(address(HUB), cfg);
  }

  function test_setHubConfig_revertsWith_InvalidParamConfig_whenCapMarkedAbsolute() public {
    IRiskSteward.HubConfig memory cfg = _defaultHubConfig();
    cfg.cap.addCap.isChangeRelative = false; // caps must be relative
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setHubConfig(address(HUB), cfg);
  }

  function test_setSpokeConfig_revertsWith_InvalidParamConfig_whenCollateralRiskAbsolute() public {
    IRiskSteward.SpokeConfig memory cfg = _defaultSpokeConfig();
    cfg.collateralRisk.isChangeRelative = false; // collateralRisk must be relative
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setSpokeConfig(address(MAIN_SPOKE), cfg);
  }

  function test_setSpokeConfig_revertsWith_InvalidParamConfig_whenDynamicMarkedRelative() public {
    IRiskSteward.SpokeConfig memory cfg = _defaultSpokeConfig();
    cfg.dynamicUpdate.collateralFactor.isChangeRelative = true; // dynamic must be absolute
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setSpokeConfig(address(MAIN_SPOKE), cfg);
  }

  function test_setSpokeConfig_revertsWith_InvalidParamConfig_whenLiquidationBonusFactorRelative()
    public
  {
    IRiskSteward.SpokeConfig memory cfg = _defaultSpokeConfig();
    cfg.liquidation.liquidationBonusFactor.isChangeRelative = true; // LBF must be absolute
    vm.prank(OWNER);
    vm.expectRevert(IRiskSteward.InvalidParamConfig.selector);
    steward.setSpokeConfig(address(MAIN_SPOKE), cfg);
  }

  function test_removeHubConfig_clearsRegistration() public {
    vm.prank(OWNER);
    steward.removeHubConfig(address(HUB));

    IEngine.AssetConfigUpdate memory u = _baseIRUpdate();
    u.irData.optimalUsageRatio = _interestRateData(HUB, ASSET).optimalUsageRatio + 1;

    skip(4 days);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.HubNotRegistered.selector);
    steward.updateHubAssetIRs(_toArray(u));
  }

  function test_removeSpokeConfig_clearsRegistration() public {
    vm.prank(OWNER);
    steward.removeSpokeConfig(address(MAIN_SPOKE));

    IEngine.LiquidationConfigUpdate memory u = _baseLiquidationUpdate();
    u.targetHealthFactor = MAIN_SPOKE.getLiquidationConfig().targetHealthFactor + 0.01e18;

    skip(4 days);
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.SpokeNotRegistered.selector);
    steward.updateSpokeLiquidationConfigs(_toArray(u));
  }

  function test_getHubConfig_returnsStored() public view {
    IRiskSteward.HubConfig memory got = steward.getHubConfig(address(HUB));
    assertEq(address(got.hubConfigurator), address(HUB_CONFIGURATOR));
    assertEq(got.rate.optimalUsageRatio.minDelay, 3 days);
    assertEq(got.rate.optimalUsageRatio.maxPercentChange, 3_00);
  }

  function test_getSpokeConfig_returnsStored() public view {
    IRiskSteward.SpokeConfig memory got = steward.getSpokeConfig(address(MAIN_SPOKE));
    assertEq(address(got.spokeConfigurator), address(SPOKE_CONFIGURATOR));
    assertEq(got.collateralRisk.minDelay, 3 days);
  }

  function test_restrictionToggles() public {
    vm.prank(OWNER);
    steward.setHubRestricted(address(HUB), true);
    assertTrue(steward.isHubRestricted(address(HUB)));

    vm.prank(OWNER);
    steward.setSpokeRestricted(address(MAIN_SPOKE), true);
    assertTrue(steward.isSpokeRestricted(address(MAIN_SPOKE)));

    vm.prank(OWNER);
    steward.setSpokeHubRestricted(address(MAIN_SPOKE), address(HUB), true);
    assertTrue(steward.isSpokeHubRestricted(address(MAIN_SPOKE), address(HUB)));

    vm.prank(OWNER);
    steward.setReserveRestricted(address(MAIN_SPOKE), address(HUB), ASSET, true);
    assertTrue(steward.isReserveRestricted(address(MAIN_SPOKE), address(HUB), ASSET));
  }
}
