// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './ReduceRiskStewardWrapper.Base.t.sol';

contract ReduceRiskStewardWrapperAccessControlTest is ReduceRiskStewardWrapperTestBase {
  function test_constructor() public view {
    assertEq(address(wrapper.RISK_STEWARD()), address(steward));
    assertEq(wrapper.RISK_COUNCIL(), REDUCE_COUNCIL);
  }

  function test_constructor_zeroRiskSteward_reverts() public {
    vm.expectRevert();
    new ReduceRiskStewardWrapper(address(0), REDUCE_COUNCIL);
  }

  function test_constructor_zeroRiskCouncil_reverts() public {
    vm.expectRevert();
    new ReduceRiskStewardWrapper(address(steward), address(0));
  }

  function test_reduceHubSpokeCaps_revertsWith_InvalidCaller() public {
    IEngine.SpokeConfigUpdate[] memory updates = _toArray(_baseSpokeCapsUpdate());
    vm.expectRevert(IReduceRiskStewardWrapper.InvalidCaller.selector);
    wrapper.reduceHubSpokeCaps(updates);
  }

  function test_addReducedDynamicReserveConfigs_revertsWith_InvalidCaller() public {
    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(_baseAddDynamic());
    vm.expectRevert(IReduceRiskStewardWrapper.InvalidCaller.selector);
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  function test_fuzz_reduceHubSpokeCaps_revertsWith_InvalidCaller(address caller) public {
    vm.assume(caller != REDUCE_COUNCIL);
    IEngine.SpokeConfigUpdate[] memory updates = _toArray(_baseSpokeCapsUpdate());
    vm.prank(caller);
    vm.expectRevert(IReduceRiskStewardWrapper.InvalidCaller.selector);
    wrapper.reduceHubSpokeCaps(updates);
  }

  function test_fuzz_addReducedDynamicReserveConfigs_revertsWith_InvalidCaller(
    address caller
  ) public {
    vm.assume(caller != REDUCE_COUNCIL);
    IEngine.DynamicReserveConfigAddition[] memory additions = _toArray(_baseAddDynamic());
    vm.prank(caller);
    vm.expectRevert(IReduceRiskStewardWrapper.InvalidCaller.selector);
    wrapper.addReducedDynamicReserveConfigs(additions);
  }

  /// @dev The wrapper is the steward's only council, so the reduce council cannot bypass the
  /// reduce-only checks by calling the steward directly.
  function test_reduceCouncil_cannotCallStewardDirectly() public {
    IHub.SpokeConfig memory current = _spokeConfig(HUB, MAIN_SPOKE, ASSET);
    IEngine.SpokeConfigUpdate memory u = _baseSpokeCapsUpdate();
    u.addCap = uint256(current.addCap) + 1;

    vm.prank(REDUCE_COUNCIL);
    vm.expectRevert(IRiskSteward.InvalidCaller.selector);
    steward.updateHubSpokeCaps(_toArray(u));
  }
}
