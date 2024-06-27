// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./CheapBuyer.sol";

// Player that buys whatever good we can get the most of each round.
contract GoldDigger is BasePlayer {
    uint8 finalAssetIndex;

    constructor(
        IGame game,
        uint8 playerIdx,
        uint8 playerCount,
        uint8 assetCount
    ) BasePlayer(game, playerIdx, playerCount, assetCount) {}

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

    function _crossedThreshold() internal view returns (bool) {
        return GAME.round() >= 14;
    }

    function createBundle(
        uint8 /* builderIdx */
    ) public virtual override returns (PlayerBundle memory bundle) {
        if (_crossedThreshold()) {
            bundle.swaps = new SwapSell[](GOODS_COUNT);
            for (uint8 i; i < GOODS_COUNT; ++i) {
                bundle.swaps[i] = SwapSell({
                    fromAssetIdx: FIRST_GOOD_IDX + i,
                    toAssetIdx: finalAssetIndex,
                    fromAmount: GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX + i)
                });
            }
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

    function buildBlock(
        PlayerBundle[] calldata bundles
    ) public virtual override returns (uint256 goldBid) {
        if (!_crossedThreshold()) {
            return 0;
        }

        uint256[] memory assetAmounts = new uint256[](ASSET_COUNT);

        uint256 assetAmountMax = 0;
        uint8 assetIndexMax = 0;

        for (uint8 i; i < GOODS_COUNT; ++i) {
            uint8 assetIndex = FIRST_GOOD_IDX + i;
            uint256 assetAmountNew = GAME.quoteSell(
                GOLD_IDX,
                assetIndex,
                (95 * GAME.balanceOf(PLAYER_IDX, GOLD_IDX)) / 100
            );

            if (assetAmountNew > assetAmountMax) {
                assetAmountMax = assetAmountNew;
                assetIndexMax = assetIndex;
            }
        }

        GAME.sell(
            GOLD_IDX,
            assetIndexMax,
            (GAME.balanceOf(PLAYER_IDX, GOLD_IDX) * 98) / 100
        );

        // Settle everyone else's bundles.
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            if (playerIdx == PLAYER_IDX) {
                // Skip our bundle.
                continue;
            }
            GAME.settleBundle(playerIdx, bundles[playerIdx]);
        }

        // Bid the gold we bought.
        return GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
    }
}
