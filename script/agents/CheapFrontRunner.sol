// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import './CheapBuyer.sol';

// Player that tries to buy whichever good is the cheapest
// AND tries to perform its swaps before everyone else.
contract CheapFrontRunner is CheapBuyer {

    constructor(IGame game, uint8 playerIdx, uint8 playerCount, uint8 assetCount)
        CheapBuyer(game, playerIdx, playerCount, assetCount) {}

    function buildBlock(PlayerBundle[] memory bundles)
        external virtual override returns (uint256 goldBid)
    {
        // Buy whatever asset we can get the most of.
        uint8 wantAssetIdx = _getMaxBuyableGood();

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

        // Settle everyone else's bundles.
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            if (playerIdx == PLAYER_IDX) {
                // Skip our bundle.
                continue;
            }
            GAME.settleBundle(playerIdx, bundles[playerIdx]);
        }
        // Bid the gold we bought.
        return goldBought;
    }
}