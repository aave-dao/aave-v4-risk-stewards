// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

contract RiskStewardHubSpokeCapsTest is RiskStewardTestBase {
  using SafeCast for uint256;

  function test_updateHubSpokeCaps() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 110) / 100; // +10% relative, within +100% bound
    u.drawCap = (uint256(current.drawCap) * 110) / 100;

    uint256 assetId = HUB.getAssetId(ASSET);
    IHub.SpokeConfig memory expected = IHub.SpokeConfig({
      addCap: u.addCap.toUint40(),
      drawCap: u.drawCap.toUint40(),
      riskPremiumThreshold: current.riskPremiumThreshold,
      active: current.active,
      halted: current.halted
    });
    vm.expectEmit(address(HUB));
    emit IHub.UpdateSpokeConfig(assetId, address(MAIN_SPOKE), expected);

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET), expected);

    IRiskSteward.HubSpokeAssetDebounce memory debounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(MAIN_SPOKE),
      ASSET
    );
    assertEq(debounce.addCap, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.drawCap, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_updateHubSpokeCaps(int256 addCapDeltaBps, int256 drawCapDeltaBps) public {
    IRiskSteward.HubCapConfig memory capBounds = steward.getHubConfig(address(HUB)).cap;
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    addCapDeltaBps = _boundDelta(addCapDeltaBps, capBounds.addCap.maxPercentChange);
    drawCapDeltaBps = _boundDelta(drawCapDeltaBps, capBounds.drawCap.maxPercentChange);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = _applyRelativeDelta({
      current: current.addCap,
      deltaBps: addCapDeltaBps,
      floor: 1 // avoid InvalidUpdateToZero
    });
    u.drawCap = _applyRelativeDelta({
      current: current.drawCap,
      deltaBps: drawCapDeltaBps,
      floor: 1 // avoid InvalidUpdateToZero
    });

    uint256 assetId = HUB.getAssetId(ASSET);
    IHub.SpokeConfig memory expected = IHub.SpokeConfig({
      addCap: u.addCap.toUint40(),
      drawCap: u.drawCap.toUint40(),
      riskPremiumThreshold: current.riskPremiumThreshold,
      active: current.active,
      halted: current.halted
    });
    vm.expectEmit(address(HUB));
    emit IHub.UpdateSpokeConfig(assetId, address(MAIN_SPOKE), expected);

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET), expected);

    IRiskSteward.HubSpokeAssetDebounce memory debounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(MAIN_SPOKE),
      ASSET
    );
    assertEq(debounce.addCap, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.drawCap, vm.getBlockTimestamp().toUint40());
  }

  function test_updateHubSpokeCaps_revertsWith_UpdateNotInRange() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 210) / 100; // +110%

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_DebounceNotRespected() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 110) / 100;
    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = (uint256(current.addCap) * 105) / 100;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    steward.updateHubSpokeCaps(_toArray(u2));
  }

  function test_updateHubSpokeCaps_revertsWith_InvalidUpdateToZero() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidUpdateToZero.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_riskPremiumThresholdChange_revertsWith_ParamChangeNotAllowed()
    public
  {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.riskPremiumThreshold = 1_00;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_activeChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.active = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_haltedChange_revertsWith_ParamChangeNotAllowed() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.halted = 1;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_ConfiguratorMismatch() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.hubConfigurator = IHubConfigurator(address(0xdead));

    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_HubIsRestricted() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setHubRestricted(address(HUB), true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.HubIsRestricted.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_SpokeIsRestricted() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setSpokeRestricted(address(MAIN_SPOKE), true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.SpokeIsRestricted.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_SpokeHubIsRestricted() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setSpokeHubRestricted(address(MAIN_SPOKE), address(HUB), true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.SpokeHubIsRestricted.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_ReserveIsRestricted() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    vm.prank(OWNER);
    steward.setReserveRestricted(address(MAIN_SPOKE), address(HUB), ASSET, true);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.ReserveIsRestricted.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }

  function test_updateHubSpokeCaps_revertsWith_NoZeroUpdates() public {
    vm.prank(RISK_COUNCIL);
    vm.expectRevert(IRiskSteward.NoZeroUpdates.selector);
    steward.updateHubSpokeCaps(new IEngine.SpokeConfigUpdate[](0));
  }

  function test_updateHubSpokeCaps_onLidoSpoke() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, LIDO_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.spoke = address(LIDO_SPOKE);
    u.drawCap = (uint256(current.drawCap) * 110) / 100;

    vm.prank(RISK_COUNCIL);
    steward.updateHubSpokeCaps(_toArray(u));

    assertEq(
      steward.getHubSpokeAssetDebounce(address(HUB), address(LIDO_SPOKE), ASSET).drawCap,
      vm.getBlockTimestamp().toUint40()
    );
  }
}
