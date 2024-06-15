// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import './BasePlayer.sol';

// Player that buys whatever good we can get the most of each round.
contract CheapBuyer is BasePlayer {

    constructor(IGame game, uint8 playerIdx, uint8 playerCount, uint8 assetCount)
            BasePlayer(game, playerIdx, playerCount, assetCount) {}

    function createBundle(uint8 /* builderIdx */)
        external virtual override returns (PlayerBundle memory bundle)
    {
        uint8 wantAssetIdx = _getMaxBuyableGood();
        bundle.swaps = new SwapSell[](ASSET_COUNT);
        // Convert 99% of every other asset to the target asset and
        // the remaining 1% to gold for our block bid.
        for (uint8 assetIdx; assetIdx < ASSET_COUNT; ++assetIdx) {
            if (assetIdx != wantAssetIdx && assetIdx != GOLD_IDX) {
                uint256 bal = GAME.balanceOf(PLAYER_IDX, assetIdx);
                bundle.swaps[assetIdx] = SwapSell({
                    fromAssetIdx: assetIdx,
                    toAssetIdx: wantAssetIdx,
                    fromAmount: bal * 99 / 100
                });
                bundle.swaps[assetIdx] = SwapSell({
                    fromAssetIdx: assetIdx,
                    toAssetIdx: GOLD_IDX,
                    fromAmount: bal * 1 / 100
                });
            }
        }
    }

    // Find the good we can buy the most of with all our other tokens.
    function _getMaxBuyableGood()
        internal view returns (uint8 maxToAssetIdx)
    {
        uint256 maxToAmount = 0;
        maxToAssetIdx = FIRST_GOOD_IDX;
        for (uint8 i; i < GOODS_COUNT; ++i) {
            uint8 toAssetIdx = FIRST_GOOD_IDX + i;
            uint256 toAmount;
            for (uint8 j; j < GOODS_COUNT; ++j) {
                uint8 fromAssetIdx = FIRST_GOOD_IDX + j;
                if (fromAssetIdx == toAssetIdx) continue;
                toAmount += GAME.quoteSell(
                    fromAssetIdx,
                    toAssetIdx,
                    GAME.balanceOf(PLAYER_IDX, fromAssetIdx)
                );
            }
            if (toAmount >= maxToAmount) {
                maxToAmount = toAmount;
                maxToAssetIdx = toAssetIdx;
            }
        }
    }
}