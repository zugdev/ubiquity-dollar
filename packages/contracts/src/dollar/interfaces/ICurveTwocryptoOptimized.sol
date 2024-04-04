// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ICurveStableSwapMetaNG} from "./ICurveStableSwapMetaNG.sol";

/**
 * @notice Curve's CurveTwocryptoOptimized interface
 *
 * @dev Differences between Curve's crypto and stable swap meta pools (and how Ubiquity organization uses them):
 * 1. They contain different tokens:
 * a) Curve's stable swap metapool containts Dollar/3CRVLP pair
 * b) Curve's crypto pool contains Governance/ETH pair
 * 2. They use different bonding curve shapes:
 * a) Curve's stable swap metapool is more straight (because underlying tokens are pegged to USD)
 * b) Curve's crypto pool resembles Uniswap's bonding curve (because underlying tokens are not USD pegged)
 *
 * @dev Basically `ICurveTwocryptoOptimized` has the same interface as `ICurveStableSwapMetaNG`
 * but we distinguish them in the code for clarity.
 */
interface ICurveTwocryptoOptimized is ICurveStableSwapMetaNG {}
