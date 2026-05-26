// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ProtocolV4TestBase} from 'aave-helpers/ProtocolV4TestBase.sol';
import {ISpoke, IHub, ITokenizationSpoke} from 'aave-address-book/AaveV4.sol';
import {Types} from 'aave-helpers/dependencies/v4/Types.sol';
import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';

import {IRiskSteward} from '../src/interfaces/IRiskSteward.sol';

/// @title RiskStewardsBase
/// @author Aave Labs
/// @notice Abstract Foundry script base for authoring v4 RiskSteward payloads. Concrete payloads
/// extend a per-chain base (e.g. `RiskStewardsEthereum`), override the relevant `xxxUpdates()`
/// virtual methods, and invoke `run(broadcastToSafe, generateDiffReport, skipTimelock)` via
/// `make run-script`. The script impersonates the council, calls each non-empty category on the
/// steward, prints the calldata for Safe submission, and optionally snapshots+diffs the protocol
/// state before/after.
abstract contract RiskStewardsBase is ProtocolV4TestBase {
  error FailedUpdate();

  uint8 public constant MAX_TX = 6;

  IRiskSteward public immutable STEWARD;

  ISpoke[] internal _spokes;
  IHub[] internal _hubs;
  ITokenizationSpoke[] internal _tokenizationSpokes;

  constructor(
    address steward,
    ISpoke[] memory spokes,
    IHub[] memory hubs,
    ITokenizationSpoke[] memory tokenizationSpokes
  ) {
    STEWARD = IRiskSteward(steward);
    for (uint256 i; i < spokes.length; i++) _spokes.push(spokes[i]);
    for (uint256 i; i < hubs.length; i++) _hubs.push(hubs[i]);
    for (uint256 i; i < tokenizationSpokes.length; i++) {
      _tokenizationSpokes.push(tokenizationSpokes[i]);
    }
  }

  function hubAssetIrUpdates() public view virtual returns (IEngine.AssetConfigUpdate[] memory) {}

  function hubSpokeCapsUpdates() public view virtual returns (IEngine.SpokeConfigUpdate[] memory) {}

  function reserveConfigUpdates()
    public
    view
    virtual
    returns (IEngine.ReserveConfigUpdate[] memory)
  {}

  function dynamicReserveConfigUpdates()
    public
    view
    virtual
    returns (IEngine.DynamicReserveConfigUpdate[] memory)
  {}

  function dynamicReserveConfigAdditions()
    public
    view
    virtual
    returns (IEngine.DynamicReserveConfigAddition[] memory)
  {}

  function spokeLiquidationConfigUpdates()
    public
    view
    virtual
    returns (IEngine.LiquidationConfigUpdate[] memory)
  {}

  function name() public pure virtual returns (string memory);

  /// @notice Entry point for the payload. This script does not broadcast directly — it's meant
  /// to be executed by the risk council via Safe.
  /// @param broadcastToSafe If true, FFI's into a Safe helper to enqueue the calldatas.
  /// @param generateDiffReport If true, snapshots protocol state before/after and writes a diff.
  /// @param skipTimelock If true, warps forward 15 days so debounce checks pass in simulation.
  function run(bool broadcastToSafe, bool generateDiffReport, bool skipTimelock) external {
    vm.startPrank(STEWARD.RISK_COUNCIL());
    bytes[] memory callDatas = _simulateAndGenerateDiff(generateDiffReport, skipTimelock);
    vm.stopPrank();

    if (callDatas.length > 1) {
      emit log_string('** multiple calldatas emitted, please execute them all **');
    }
    emit log_string('safe address');
    emit log_address(STEWARD.RISK_COUNCIL());
    emit log_string('steward address:');
    emit log_address(address(STEWARD));

    for (uint8 i; i < callDatas.length; i++) {
      emit log_string('calldata:');
      emit log_bytes(callDatas[i]);

      if (broadcastToSafe) {
        _sendToSafe(callDatas[i]);
      }
    }
  }

  function _simulateAndGenerateDiff(
    bool generateDiffReport,
    bool skipTimelock
  ) internal returns (bytes[] memory) {
    bytes[] memory callDatas = new bytes[](MAX_TX);
    uint8 txCount;

    string memory pre = string.concat('pre_', name());
    string memory post = string.concat('post_', name());

    IEngine.AssetConfigUpdate[] memory irUpdates = hubAssetIrUpdates();
    IEngine.SpokeConfigUpdate[] memory capUpdates = hubSpokeCapsUpdates();
    IEngine.ReserveConfigUpdate[] memory reserveUpdates = reserveConfigUpdates();
    IEngine.DynamicReserveConfigUpdate[] memory dynUpdates = dynamicReserveConfigUpdates();
    IEngine.DynamicReserveConfigAddition[] memory dynAdds = dynamicReserveConfigAdditions();
    IEngine.LiquidationConfigUpdate[] memory liqUpdates = spokeLiquidationConfigUpdates();

    if (skipTimelock) {
      vm.warp(vm.getBlockTimestamp() + 15 days);
    }

    if (generateDiffReport) {
      Types.V4Snapshot memory snapBefore = createV4Snapshot(_spokes, _hubs);
      writeV4SnapshotJson(pre, snapBefore);
    }

    if (irUpdates.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.updateHubAssetIRs, (irUpdates));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (capUpdates.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.updateHubSpokeCaps, (capUpdates));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (reserveUpdates.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.updateReserveConfigs, (reserveUpdates));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (dynUpdates.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.updateDynamicReserveConfigs, (dynUpdates));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (dynAdds.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.addDynamicReserveConfigs, (dynAdds));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (liqUpdates.length != 0) {
      callDatas[txCount] = abi.encodeCall(IRiskSteward.updateSpokeLiquidationConfigs, (liqUpdates));
      (bool success, bytes memory resultData) = address(STEWARD).call(callDatas[txCount]);
      _verifyCallResult(success, resultData);
      txCount++;
    }

    if (generateDiffReport) {
      Types.V4Snapshot memory snapAfter = createV4Snapshot(_spokes, _hubs);
      writeV4SnapshotJson(post, snapAfter);
      diffV4Snapshots(name());
    }

    assembly {
      mstore(callDatas, txCount)
    }
    return callDatas;
  }

  function _sendToSafe(bytes memory callData) internal {
    string[] memory inputs = new string[](8);
    inputs[0] = 'npx';
    inputs[1] = 'tsx';
    inputs[2] = 'scripts/safe-helper.ts';
    inputs[3] = vm.toString(STEWARD.RISK_COUNCIL());
    inputs[4] = vm.toString(address(STEWARD));
    inputs[5] = vm.toString(callData);
    inputs[6] = vm.toString(block.chainid);
    inputs[7] = 'Call';
    vm.ffi(inputs);
  }

  function _verifyCallResult(bool success, bytes memory returnData) private pure {
    if (success) return;
    if (returnData.length > 0) {
      // solhint-disable-next-line no-inline-assembly
      assembly {
        let returndata_size := mload(returnData)
        revert(add(32, returnData), returndata_size)
      }
    } else {
      revert FailedUpdate();
    }
  }
}
