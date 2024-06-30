// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import './CheapBuyer.sol';


// Player that buys whatever good we can get the most of each round.
contract BigSandwich is CheapBuyer {

    mapping (uint8 => int256) assetsSold;

    constructor(IGame game, uint8 playerIdx, uint8 playerCount, uint8 assetCount)
            CheapBuyer(game, playerIdx, playerCount, assetCount) {}

    
    function _getMaxSold() internal view returns (uint8 maxToAssetIdx) {
        int256 maxToAmount = 0;
        maxToAssetIdx = 0;

        for (uint8 i; i < ASSET_COUNT; ++i) {
            if (assetsSold[i] >= maxToAmount) {
                maxToAmount = assetsSold[i];
                maxToAssetIdx = i;
            }
        }
    }

    function buildBlock(PlayerBundle[] calldata bundles)
        public virtual override returns (uint256 goldBid)
    {
        // Check which asset everyone is selling the most of.
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            PlayerBundle memory bundle = bundles[playerIdx];

            for(uint256 i = 0; i < bundle.swaps.length; i++) {
                SwapSell memory swap = bundle.swaps[i];
                assetsSold[swap.fromAssetIdx] += int256(swap.fromAmount);
                assetsSold[swap.toAssetIdx] -= int256(GAME.quoteSell(swap.fromAssetIdx, swap.toAssetIdx, swap.fromAmount));
            }

        }

        // Settle everyone else's bundles.
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            if (playerIdx == PLAYER_IDX) {
                // Skip our bundle.
                continue;
            }
            GAME.settleBundle(playerIdx, bundles[playerIdx]);
        }

        // Buy whatever asset everyone is selling the most of.
        uint8 wantAssetIdx = _getMaxSold();

        // Sell 5% of all the other goods for gold and the
        // remaining for the asset we want.
        uint256 goldBought;
        for (uint8 i; i < GOODS_COUNT; ++i) {
            uint8 assetIdx = FIRST_GOOD_IDX + i;
            if (assetIdx != wantAssetIdx) {
                goldBought += GAME.sell(
                    assetIdx,
                    GOLD_IDX,
                    GAME.balanceOf(PLAYER_IDX, assetIdx) * 5 / 100
                );
                GAME.sell(
                    assetIdx,
                    wantAssetIdx,
                    GAME.balanceOf(PLAYER_IDX, assetIdx) * 95 / 100
                );
            }
        }

        // Bid the gold we bought.
        return goldBought;
    }    
}
