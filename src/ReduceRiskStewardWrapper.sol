// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {EngineFlags} from 'aave-v4/config-engine/libraries/EngineFlags.sol';

import {IAaveV4ConfigEngine as IEngine} from 'aave-v4/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHub} from 'aave-v4/hub/interfaces/IHub.sol';
import {ISpoke} from 'aave-v4/spoke/interfaces/ISpoke.sol';

import {IRiskSteward} from 'src/interfaces/IRiskSteward.sol';
import {IReduceRiskStewardWrapper} from 'src/interfaces/IReduceRiskStewardWrapper.sol';

/// @title ReduceRiskStewardWrapper
/// @author Aave Labs
/// @notice Reduce-only front for a dedicated `RiskSteward`. Risk Council is the only address
/// allowed to invoke the reduce entrypoints; each one checks the update lowers the risk against
/// the values currently set in the market before forwarding it to the steward.
contract ReduceRiskStewardWrapper is IReduceRiskStewardWrapper {
  /// @inheritdoc IReduceRiskStewardWrapper
  IRiskSteward public immutable RISK_STEWARD;

  /// @inheritdoc IReduceRiskStewardWrapper
  address public immutable RISK_COUNCIL;

  modifier onlyRiskCouncil() {
    require(msg.sender == RISK_COUNCIL, InvalidCaller());
    _;
  }

  /// @dev Constructor.
  /// @param riskSteward_ The wrapped steward, whose `RISK_COUNCIL` must be this contract.
  /// @param riskCouncil_ The council address authorized to call the reduce entrypoints.
  constructor(address riskSteward_, address riskCouncil_) {
    require(IRiskSteward(riskSteward_).RISK_COUNCIL() == address(this));
    require(riskCouncil_ != address(0));
    RISK_STEWARD = IRiskSteward(riskSteward_);
    RISK_COUNCIL = riskCouncil_;
  }

  /// @inheritdoc IReduceRiskStewardWrapper
  function reduceHubSpokeCaps(
    IEngine.SpokeConfigUpdate[] calldata updates
  ) external onlyRiskCouncil {
    for (uint256 i; i < updates.length; ++i) {
      IHub hub = IHub(updates[i].hub);
      IHub.SpokeConfig memory current = hub.getSpokeConfig(
        hub.getAssetId(updates[i].underlying),
        updates[i].spoke
      );
      _requireReduction(current.addCap, updates[i].addCap);
      _requireReduction(current.drawCap, updates[i].drawCap);
    }
    RISK_STEWARD.updateHubSpokeCaps(updates);
  }

  /// @inheritdoc IReduceRiskStewardWrapper
  function addReducedDynamicReserveConfigs(
    IEngine.DynamicReserveConfigAddition[] calldata additions
  ) external onlyRiskCouncil {
    for (uint256 i; i < additions.length; ++i) {
      ISpoke spoke = ISpoke(additions[i].spoke);
      uint256 reserveId = spoke.getReserveId(
        additions[i].hub,
        IHub(additions[i].hub).getAssetId(additions[i].underlying)
      );
      ISpoke.DynamicReserveConfig memory latest = spoke.getDynamicReserveConfig(
        reserveId,
        spoke.getReserve(reserveId).dynamicConfigKey
      );

      ISpoke.DynamicReserveConfig calldata newConfig = additions[i].dynamicConfig;
      require(newConfig.collateralFactor < latest.collateralFactor, UpdateNotReducing());
      require(
        newConfig.maxLiquidationBonus >= latest.maxLiquidationBonus &&
          uint256(newConfig.maxLiquidationBonus) * newConfig.collateralFactor <=
            uint256(latest.maxLiquidationBonus) * latest.collateralFactor,
        InvalidLiquidationBonus()
      );
    }
    RISK_STEWARD.addDynamicReserveConfigs(additions);
  }

  function _requireReduction(uint256 currentValue, uint256 newValue) internal pure {
    require(newValue == EngineFlags.KEEP_CURRENT || newValue < currentValue, UpdateNotReducing());
  }
}
