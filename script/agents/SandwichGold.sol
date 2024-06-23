// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./BasePlayer.sol";
import "forge-std/console.sol";

// Player that buys whatever good we can get the most of each round.
contract SandwichGold is BasePlayer {
    uint8 finalAssetIndex;

    constructor(
        IGame game,
        uint8 playerIdx,
        uint8 playerCount,
        uint8 assetCount
    ) BasePlayer(game, playerIdx, playerCount, assetCount) {}

    function maxNum(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    function minNum(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    // Find the good (non-gold asset) we have the lowest balance of and not 0.
    function _getMinNonZeroGood() internal view returns (uint8 minAssetIdx) {
        minAssetIdx = FIRST_GOOD_IDX;
        uint256 minBalance = GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX);
        for (uint8 i = 1; i < GOODS_COUNT; ++i) {
            uint8 assetIdx = FIRST_GOOD_IDX + i;
            uint256 bal = GAME.balanceOf(PLAYER_IDX, assetIdx);
            if (bal > 0) {
                if (minBalance >= bal) {
                    minAssetIdx = assetIdx;
                    minBalance = bal;
                }
            }
        }
    }

    function _getCheapestAssetForGold(
        uint256 goldAmount
    ) internal view returns (uint8 cheapestAssetIdx, uint256 assetAmountMax) {
        uint8 assetIndexMax = 0;

        for (uint8 i; i < GOODS_COUNT; ++i) {
            uint8 assetIndex = FIRST_GOOD_IDX + i;
            uint256 assetAmountNew = GAME.quoteSell(
                GOLD_IDX,
                assetIndex,
                goldAmount
            );

            if (assetAmountNew > assetAmountMax) {
                assetAmountMax = assetAmountNew;
                assetIndexMax = assetIndex;
            }
        }

        cheapestAssetIdx = assetIndexMax;
    }

    function createBundle(
        uint8 /* builderIdx */
    ) external virtual override returns (PlayerBundle memory bundle) {
        if (GAME.round() == 32) {
            bundle.swaps = new SwapSell[](1);
            (uint8 assetIndexMax, ) = _getCheapestAssetForGold(
                GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
            );
            bundle.swaps[0] = SwapSell({
                fromAssetIdx: GOLD_IDX,
                toAssetIdx: assetIndexMax,
                fromAmount: GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
            });
        } else {
            bundle.swaps = new SwapSell[](GOODS_COUNT);
            for (uint8 i; i < GOODS_COUNT; ++i) {
                bundle.swaps[i] = SwapSell({
                    fromAssetIdx: FIRST_GOOD_IDX + i,
                    toAssetIdx: GOLD_IDX,
                    fromAmount: GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX + i)
                });
            }
        }
    }

    function findMaxInList(
        int256[] memory list
    ) internal pure returns (uint256 maxIndex) {
        int256 max = list[0];
        for (uint256 i = 1; i < list.length; i++) {
            if (list[i] > max) {
                max = list[i];
                maxIndex = i;
            }
        }
    }

    function sandwichBundleWithGold(
        uint8 playerIdx,
        PlayerBundle memory bundle
    ) internal returns (uint256 goldProfit) {
        uint256 initialGold = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
        int256[] memory assetAmounts = new int256[](ASSET_COUNT);

        for (uint256 i; i < bundle.swaps.length; i++) {
            SwapSell memory swap = bundle.swaps[i];

            assetAmounts[swap.toAssetIdx] += int256(
                GAME.quoteSell(
                    swap.fromAssetIdx,
                    swap.toAssetIdx,
                    swap.fromAmount
                )
            );

            assetAmounts[swap.fromAssetIdx] -= int256(swap.fromAmount);
        }

        uint8 assetIndexMax = uint8(findMaxInList(assetAmounts));

        GAME.sell(
            GOLD_IDX,
            assetIndexMax,
            GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
        );

        GAME.settleBundle(playerIdx, bundle);

        GAME.sell(
            assetIndexMax,
            GOLD_IDX,
            GAME.balanceOf(PLAYER_IDX, assetIndexMax)
        );

        goldProfit = GAME.balanceOf(PLAYER_IDX, GOLD_IDX) - initialGold;
    }

    function buildBlock(
        PlayerBundle[] memory bundles
    ) external virtual override returns (uint256 goldBid) {
        uint256 bidAmount = 0;
        uint256 goldReceivedIfFirst = 0;

        (uint8 assetIndexMax, uint256 assetAmount) = _getCheapestAssetForGold(
            GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
        );

        // If you can directly buy 64 of the asset, do it.
        if (assetAmount >= 64e18) {
            GAME.buy(GOLD_IDX, assetIndexMax, 64e18);

            // Settle everyone else's bundles.
            for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
                if (playerIdx == PLAYER_IDX) {
                    // Skip our bundle.
                    continue;
                }

                sandwichBundleWithGold(playerIdx, bundles[playerIdx]);
            }
            bidAmount = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
        } else {
            // Sell everything we have first for gold
            for (uint8 i; i < GOODS_COUNT; ++i) {
                goldReceivedIfFirst += GAME.sell(
                    FIRST_GOOD_IDX + i,
                    GOLD_IDX,
                    GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX + i)
                );
            }

            uint256 totalSandwichProfit = 0;

            // Settle everyone else's bundles with sandwiches
            for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
                if (playerIdx == PLAYER_IDX) {
                    // Skip our bundle.
                    continue;
                }
                totalSandwichProfit += sandwichBundleWithGold(
                    playerIdx,
                    bundles[playerIdx]
                );
            }

            // Check if at the end of the block we can win
            (assetIndexMax, assetAmount) = _getCheapestAssetForGold(
                GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
            );

            // If enough gold to win then bid everything else, and win
            if (assetAmount >= 64e18) {
                GAME.buy(GOLD_IDX, assetIndexMax, 64e18);
                bidAmount = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
            } else {
                bidAmount = (totalSandwichProfit * 90) / 100;
            }
        }

        return bidAmount;
    }
}
