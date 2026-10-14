// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './RiskSteward.Base.t.sol';

import {
  ReduceRiskStewardWrapper,
  IReduceRiskStewardWrapper
} from 'src/ReduceRiskStewardWrapper.sol';

/// @dev Replaces the base `steward` with one whose council is the wrapper, so every steward
/// helper in `RiskStewardTestBase` reads the instance the wrapper drives.
contract ReduceRiskStewardWrapperTestBase is RiskStewardTestBase {
  address internal immutable REDUCE_COUNCIL = makeAddr('REDUCE_COUNCIL');
  address internal immutable GOVERNANCE = makeAddr('GOVERNANCE');

  ReduceRiskStewardWrapper internal wrapper;

  function setUp() public virtual override {
    super.setUp();

    address predictedWrapper = vm.computeCreateAddress(
      address(this),
      vm.getNonce(address(this)) + 1
    );
    steward = new RiskSteward(predictedWrapper, OWNER);
    wrapper = new ReduceRiskStewardWrapper(address(steward), REDUCE_COUNCIL);
    assertEq(steward.RISK_COUNCIL(), address(wrapper));

    vm.prank(OWNER);
    steward.setConfig(_defaultConfig());

    address defaultAdmin = ACCESS_MANAGER.getRoleMember(Roles.ACCESS_MANAGER_ADMIN_ROLE, 0);
    vm.startPrank(defaultAdmin);
    ACCESS_MANAGER.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, address(steward), 0);
    ACCESS_MANAGER.grantRole(Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE, GOVERNANCE, 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE, GOVERNANCE, 0);
    vm.stopPrank();

    vm.label(address(wrapper), 'REDUCE_WRAPPER');
    vm.label(address(steward), 'REDUCE_STEWARD');
  }

  function _reserveId(ISpoke spoke, IHub hub, address underlying) internal view returns (uint256) {
    return spoke.getReserveId(address(hub), hub.getAssetId(underlying));
  }

  /// @dev Lowers `collateralFactor` on the latest key, keeping the other dynamic fields.
  function _baseReducedAddDynamic(
    uint16 collateralFactor
  ) internal view returns (IEngine.DynamicReserveConfigAddition memory) {
    IEngine.DynamicReserveConfigAddition memory u = _baseAddDynamic();
    u.dynamicConfig.collateralFactor = collateralFactor;
    return u;
  }
}
