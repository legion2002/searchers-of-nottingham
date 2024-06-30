// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "src/game/Markets.sol";
import "./BasePlayer.sol";

import "forge-std/console2.sol";

// Player that buys whatever good we can get the most of each round.
contract SandwichCheap is AssetMarket, IPlayer {
    // The game instance.
    IGame internal immutable GAME;
    // Our player index.
    uint8 internal immutable PLAYER_IDX;
    // How many players are in the game.
    uint8 internal immutable PLAYER_COUNT;
    // How many goods (assets that aren't gold) are in the game.
    uint8 internal immutable GOODS_COUNT;
    // Maximum number of swaps allowed in a single player bundle.
    uint8 internal immutable MAX_SWAPS_PER_BUNDLE;

    constructor(
        IGame game,
        uint8 playerIdx,
        uint8 playerCount,
        uint8 assetCount
    ) AssetMarket(assetCount) {
        GAME = game;
        PLAYER_IDX = playerIdx;
        PLAYER_COUNT = playerCount;
        ASSET_COUNT = assetCount;
        GOODS_COUNT = ASSET_COUNT - 1;
        MAX_SWAPS_PER_BUNDLE = ASSET_COUNT * (ASSET_COUNT - 1);
    }

    uint8 kingAsset;

    function _getCheapestAsset(
        uint256[] memory reserves
    ) internal returns (uint8 cheapestAssetIdx, uint256 assetAmountMax) {
        _storeReserves(reserves);
        uint8 assetIndexMax = 0;

        for (uint8 i; i < GOODS_COUNT; ++i) {
            uint8 assetIndex = FIRST_GOOD_IDX + i;
            uint256 assetAmountNew = 0;

            // Sell everything
            for (uint8 sellIndex; sellIndex <= GOODS_COUNT; sellIndex++) {
                assetAmountNew = _sell(
                    sellIndex,
                    assetIndex,
                    GAME.balanceOf(PLAYER_IDX, sellIndex)
                );
            }

            if (assetAmountNew > assetAmountMax) {
                assetAmountMax = assetAmountNew;
                assetIndexMax = assetIndex;
            }
        }

        cheapestAssetIdx = assetIndexMax;
    }

    function createBundle(
        uint8 builderIdx
    ) public virtual override returns (PlayerBundle memory bundle) {
        // TODO: Add check here that sells everything for 1 asset if this is round 32
        if (builderIdx % 4 == 0) {
            require(false, "I have no bundle");
        } else if (builderIdx % 4 == 1) {
            bundle = PlayerBundle({swaps: new SwapSell[](1)});
            bundle.swaps[0] = SwapSell({
                fromAssetIdx: GOLD_IDX,
                toAssetIdx: FIRST_GOOD_IDX,
                fromAmount: GAME.balanceOf(PLAYER_IDX, GOLD_IDX) + 1000
            });
        } else if (builderIdx % 4 == 2) {
            bundle = PlayerBundle({swaps: new SwapSell[](1)});
            bundle.swaps[0] = SwapSell({
                fromAssetIdx: GOLD_IDX,
                toAssetIdx: 100,
                fromAmount: GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
            });
        } else {
            uint8 first = FIRST_GOOD_IDX;
            uint8 second = FIRST_GOOD_IDX + 1;

            uint256 initialFirst = GAME.balanceOf(PLAYER_IDX, first);
            uint256 initialSecond = GAME.balanceOf(PLAYER_IDX, second);

            bundle = PlayerBundle({swaps: new SwapSell[](12)});

            for (uint256 i; i < bundle.swaps.length; i++) {
                bundle.swaps[i] = SwapSell({
                    fromAssetIdx: i % 2 == 0 ? first : second,
                    toAssetIdx: i % 2 == 0 ? second : first,
                    fromAmount: GAME.balanceOf(
                        PLAYER_IDX,
                        i % 2 == 0 ? first : second
                    )
                });
            }

            require(
                initialFirst <= GAME.balanceOf(PLAYER_IDX, first) &&
                    initialSecond <= GAME.balanceOf(PLAYER_IDX, second),
                "Loss"
            );
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

    function findMinInList(
        int256[] memory list
    ) internal pure returns (uint256 minIndex) {
        int256 min = list[0];
        for (uint256 i = 1; i < list.length; i++) {
            if (list[i] < min) {
                min = list[i];
                minIndex = i;
            }
        }
    }

    function getMostBought(
        PlayerBundle[] calldata bundles
    ) internal returns (uint8 assetBoughtMost) {
        _storeReserves(GAME.marketState());

        int256[] memory assetAmounts = new int256[](ASSET_COUNT);

        // Simulating all bundles
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            if (playerIdx == PLAYER_IDX) {
                // Skip our bundle.
                continue;
            }

            // For each bundle
            PlayerBundle memory bundle = bundles[playerIdx];

            // Test each swap
            bytes memory testNull = abi.encode(bundle);

            if (testNull.length == 0) {
                continue;
            }

            bool[] memory skipSwap = new bool[](bundle.swaps.length);

            for (uint256 i; i < bundle.swaps.length; i++) {
                SwapSell memory swap = bundle.swaps[i];
                try
                    GAME.quoteSell(
                        swap.fromAssetIdx,
                        swap.toAssetIdx,
                        swap.fromAmount
                    )
                returns (uint256 toAmount) {
                    assetAmounts[swap.toAssetIdx] += int256(toAmount);
                    assetAmounts[swap.fromAssetIdx] -= int256(swap.fromAmount);
                } catch {
                    skipSwap[i] = true;
                }
            }

            uint8 assetIndexMax = uint8(findMaxInList(assetAmounts));

            // Sell everything we have for sandwich asset
            for (uint8 i; i <= GOODS_COUNT; i++) {
                _sell(i, assetIndexMax, GAME.balanceOf(PLAYER_IDX, i));
            }

            // Simulate the bundle
            for (uint8 i; i < bundle.swaps.length; i++) {
                if (skipSwap[i]) {
                    continue;
                }

                _sell(
                    bundle.swaps[i].fromAssetIdx,
                    bundle.swaps[i].toAssetIdx,
                    bundle.swaps[i].fromAmount
                );
            }
        }

        assetBoughtMost = uint8(findMaxInList(assetAmounts));

        // if (assetAmounts[GOLD_IDX] < 0) {
        //     buyGoldFirst = true;
        // } else {
        //     buyGoldFirst = false;
        // }
    }

    function sandwichBundle(
        uint8 playerIdx,
        PlayerBundle memory bundle
    ) internal {
        int256[] memory assetAmounts = new int256[](ASSET_COUNT);

        bytes memory testNull = abi.encode(bundle);
        bool salmonellaBundle = false;

        if (testNull.length == 0) {
            GAME.settleBundle(playerIdx, bundle);
            return;
        }

        for (uint256 i; i < bundle.swaps.length; i++) {
            SwapSell memory swap = bundle.swaps[i];
            try
                GAME.quoteSell(
                    swap.fromAssetIdx,
                    swap.toAssetIdx,
                    swap.fromAmount
                )
            returns (uint256 toAmount) {
                assetAmounts[swap.toAssetIdx] += int256(toAmount);
                assetAmounts[swap.fromAssetIdx] -= int256(swap.fromAmount);
            } catch {
                salmonellaBundle = true;
            }
        }

        uint8 assetIndexMax = uint8(findMaxInList(assetAmounts));

        if (salmonellaBundle) {
            GAME.settleBundle(playerIdx, bundle);
            return;
        }

        // for (uint8 i; i <= GOODS_COUNT; i++) {
        //     GAME.sell(i, assetIndexMax, GAME.balanceOf(PLAYER_IDX, i));
        // }

        GAME.sell(
            kingAsset,
            assetIndexMax,
            GAME.balanceOf(PLAYER_IDX, kingAsset)
        );

        GAME.settleBundle(playerIdx, bundle);

        GAME.sell(
            assetIndexMax,
            kingAsset,
            GAME.balanceOf(PLAYER_IDX, assetIndexMax)
        );
    }

    function buildBlock(
        PlayerBundle[] calldata bundles
    ) public virtual override returns (uint256 goldBid) {
        uint256 bidAmount = 0;
        uint256 kingReceivedIfFirst = 0;

        kingAsset = getMostBought(bundles);

        // 1. Sell everything we have first for king asset
        for (uint8 i; i < GOODS_COUNT; ++i) {
            kingReceivedIfFirst += GAME.sell(
                FIRST_GOOD_IDX + i,
                kingAsset,
                GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX + i)
            );
        }

        uint256 initialKingAmount = GAME.balanceOf(PLAYER_IDX, kingAsset);

        // 2. Settle everyone else's bundles with sandwiches
        for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
            if (playerIdx == PLAYER_IDX) {
                // Skip our bundle.
                continue;
            }

            sandwichBundle(playerIdx, bundles[playerIdx]);
        }

        // Get the cheapest asset
        (
            uint8 cheapestAssetIndex,
            uint256 cheapestAssetAmount
        ) = _getCheapestAsset(GAME.marketState());

        // 3. If enough asset to win then bid everything else
        if (cheapestAssetAmount > 64e18) {
            // Sell everything we have for the cheapest asset
            GAME.buy(kingAsset, cheapestAssetIndex, 64e18);

            GAME.sell(
                kingAsset,
                GOLD_IDX,
                GAME.balanceOf(PLAYER_IDX, kingAsset)
            );

            bidAmount = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
        } else {
            // Find the total profit from this trade
            uint256 totalProfit = GAME.balanceOf(PLAYER_IDX, kingAsset) >
                initialKingAmount
                ? GAME.balanceOf(PLAYER_IDX, kingAsset) - initialKingAmount
                : 0;

            // Bid everything except 1 wei of profit
            bidAmount = GAME.sell(
                kingAsset,
                GOLD_IDX,
                (totalProfit * 99) / 100
            );
        }

        return bidAmount;
    }
}
