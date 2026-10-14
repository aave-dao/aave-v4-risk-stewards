// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './ReduceRiskStewardWrapper.Base.t.sol';

contract ReduceRiskStewardWrapperHubSpokeCapsTest is ReduceRiskStewardWrapperTestBase {
  using SafeCast for uint256;

  function test_reduceHubSpokeCaps() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 90) / 100;
    u.drawCap = (uint256(current.drawCap) * 80) / 100;

    IHub.SpokeConfig memory expected = IHub.SpokeConfig({
      addCap: u.addCap.toUint40(),
      drawCap: u.drawCap.toUint40(),
      riskPremiumThreshold: current.riskPremiumThreshold,
      active: current.active,
      halted: current.halted
    });
    vm.expectEmit(address(HUB));
    emit IHub.UpdateSpokeConfig(HUB.getAssetId(ASSET), address(MAIN_SPOKE), expected);

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET), expected);

    IRiskSteward.HubSpokeAssetDebounce memory debounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(MAIN_SPOKE),
      ASSET
    );
    assertEq(debounce.addCap, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.drawCap, vm.getBlockTimestamp().toUint40());
  }

  function test_fuzz_reduceHubSpokeCaps(uint256 addCap, uint256 drawCap) public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = bound(addCap, 0, current.addCap - 1);
    u.drawCap = bound(drawCap, 0, current.drawCap - 1);

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    IHub.SpokeConfig memory updated = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    assertEq(updated.addCap, u.addCap);
    assertEq(updated.drawCap, u.drawCap);
  }

  function test_reduceHubSpokeCaps_toZero() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    u.drawCap = 0;

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    IHub.SpokeConfig memory updated = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    assertEq(updated.addCap, 0);
    assertEq(updated.drawCap, 0);
  }

  function test_reduceHubSpokeCaps_onlyAddCap_keepsDrawCap() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) - 1;

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    IHub.SpokeConfig memory updated = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    assertEq(updated.addCap, u.addCap);
    assertEq(updated.drawCap, current.drawCap);

    IRiskSteward.HubSpokeAssetDebounce memory debounce = steward.getHubSpokeAssetDebounce(
      address(HUB),
      address(MAIN_SPOKE),
      ASSET
    );
    assertEq(debounce.addCap, vm.getBlockTimestamp().toUint40());
    assertEq(debounce.drawCap, 0);
  }

  function test_reduceHubSpokeCaps_onlyDrawCap_keepsAddCap() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.drawCap = uint256(current.drawCap) - 1;

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    IHub.SpokeConfig memory updated = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    assertEq(updated.addCap, current.addCap);
    assertEq(updated.drawCap, u.drawCap);
  }

  function test_reduceHubSpokeCaps_multipleSpokes() public {
    IHub.SpokeConfig memory mainCurrent = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    IHub.SpokeConfig memory lidoCurrent = _spokeConfig(HUB, LIDO_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate[] memory updates = new IEngine.SpokeConfigUpdate[](2);
    updates[0] = _baseSpokeCapsUpdate();
    updates[0].addCap = uint256(mainCurrent.addCap) / 2;
    updates[1] = _baseSpokeCapsUpdate();
    updates[1].spoke = address(LIDO_SPOKE);
    updates[1].drawCap = uint256(lidoCurrent.drawCap) / 2;

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(updates);

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, updates[0].addCap);
    assertEq(_spokeConfig(HUB, LIDO_SPOKE, ASSET).drawCap, updates[1].drawCap);
  }

  function test_reduceHubSpokeCaps_addCapIncrease_revertsWith_UpdateNotReducing() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_reduceHubSpokeCaps_drawCapIncrease_revertsWith_UpdateNotReducing() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.drawCap = uint256(current.drawCap) + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_reduceHubSpokeCaps_sameValue_revertsWith_UpdateNotReducing() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = current.addCap;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_fuzz_reduceHubSpokeCaps_increase_revertsWith_UpdateNotReducing(
    uint256 addCap,
    uint256 drawCap,
    bool increaseAddCap
  ) public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    if (increaseAddCap) {
      u.addCap = bound(addCap, current.addCap, EngineFlags.KEEP_CURRENT - 1);
      u.drawCap = bound(drawCap, 0, current.drawCap - 1);
    } else {
      u.addCap = bound(addCap, 0, current.addCap - 1);
      u.drawCap = bound(drawCap, current.drawCap, EngineFlags.KEEP_CURRENT - 1);
    }

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  /// @dev One increasing entry reverts the whole batch, including the valid reductions before it.
  function test_reduceHubSpokeCaps_increaseInBatch_revertsWith_UpdateNotReducing() public {
    IHub.SpokeConfig memory mainCurrent = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    IHub.SpokeConfig memory lidoCurrent = _spokeConfig(HUB, LIDO_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate[] memory updates = new IEngine.SpokeConfigUpdate[](2);
    updates[0] = _baseSpokeCapsUpdate();
    updates[0].addCap = uint256(mainCurrent.addCap) / 2;
    updates[1] = _baseSpokeCapsUpdate();
    updates[1].spoke = address(LIDO_SPOKE);
    updates[1].addCap = uint256(lidoCurrent.addCap) + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(updates);
  }

  /// @dev A second reduction is measured against the value the first one set, not the original.
  function test_reduceHubSpokeCaps_measuredAgainstLiveValue_afterPriorReduction() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) / 2;
    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    skip(steward.getConfig().hub.cap.addCap.minDelay);

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = (uint256(current.addCap) * 3) / 4; // below the original, above the live value
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IReduceRiskStewardWrapper.UpdateNotReducing.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u2));
  }

  /// @dev After governance raises a cap, a reduction is measured against the raised value.
  function test_reduceHubSpokeCaps_measuredAgainstLiveValue_afterGovernanceRaise() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    uint256 raisedAddCap = uint256(current.addCap) * 2;

    uint256 assetId = HUB.getAssetId(ASSET);

    vm.prank(GOVERNANCE);
    HUB_CONFIGURATOR.updateSpokeAddCap(address(HUB), assetId, address(MAIN_SPOKE), raisedAddCap);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = raisedAddCap - 1; // above the original cap, below the live one
    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, u.addCap);
  }

  /// @dev Both entries are checked against the pre-batch value; the last one wins on-chain, and it
  /// is still a reduction.
  function test_reduceHubSpokeCaps_duplicateInBatch_lastWins() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate[] memory updates = new IEngine.SpokeConfigUpdate[](2);
    updates[0] = _baseSpokeCapsUpdate();
    updates[0].addCap = uint256(current.addCap) / 2;
    updates[1] = _baseSpokeCapsUpdate();
    updates[1].addCap = (uint256(current.addCap) * 3) / 4;

    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(updates);

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, updates[1].addCap);
    assertLt(updates[1].addCap, current.addCap);
  }

  function test_reduceHubSpokeCaps_emptyUpdates_revertsWith_NoZeroUpdates() public {
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.NoZeroUpdates.selector);
    wrapper.reduceHubSpokeCaps(new IEngine.SpokeConfigUpdate[](0));
  }

  function test_reduceHubSpokeCaps_beyondStewardBound_revertsWith_UpdateNotInRange() public {
    IRiskSteward.Config memory cfg = _defaultConfig();
    cfg.hub.cap.addCap.maxPercentChange = 10_00;
    vm.prank(OWNER);
    steward.setConfig(cfg);

    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 80) / 100; // -20%

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.UpdateNotInRange.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_reduceHubSpokeCaps_tooSoon_revertsWith_DebounceNotRespected() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 90) / 100;
    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    skip(steward.getConfig().hub.cap.addCap.minDelay - 1);

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = (uint256(current.addCap) * 80) / 100;
    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.DebounceNotRespected.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u2));
  }

  function test_reduceHubSpokeCaps_afterDelay_succeeds() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = (uint256(current.addCap) * 90) / 100;
    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u));

    skip(steward.getConfig().hub.cap.addCap.minDelay);

    IEngine.SpokeConfigUpdate memory u2 = _baseSpokeCapsUpdate();
    u2.addCap = (uint256(current.addCap) * 80) / 100;
    vm.prank(REDUCE_COUNCIL);
    wrapper.reduceHubSpokeCaps(_toArray(u2));

    assertEq(_spokeConfig(HUB, MAIN_SPOKE, ASSET).addCap, u2.addCap);
  }

  function test_reduceHubSpokeCaps_otherField_revertsWith_ParamChangeNotAllowed() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    u.active = EngineFlags.DISABLED;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.ParamChangeNotAllowed.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_reduceHubSpokeCaps_whenSpokeRestricted_revertsWith_RestrictedAddress() public {
    vm.prank(OWNER);
    steward.setAddressRestricted(address(MAIN_SPOKE), true);

    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(
      abi.encodeWithSelector(IRiskSteward.RestrictedAddress.selector, address(MAIN_SPOKE))
    );
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }

  function test_reduceHubSpokeCaps_configuratorMismatch_revertsWith_ConfiguratorMismatch() public {
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = 0;
    u.hubConfigurator = IHubConfigurator(address(0xdead));

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.ConfiguratorMismatch.selector);
    wrapper.reduceHubSpokeCaps(_toArray(u));
  }
}
