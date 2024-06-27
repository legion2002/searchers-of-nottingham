// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./BasePlayer.sol";
import "forge-std/console.sol";
import "src/game/Markets.sol";

// // Player that buys whatever good we can get the most of each round.
// contract SmartSeller is AssetMarket, IPlayer {
//     // The game instance.
//     IGame internal immutable GAME;
//     // Our player index.
//     uint8 internal immutable PLAYER_IDX;
//     // How many players are in the game.
//     uint8 internal immutable PLAYER_COUNT;
//     // How many goods (assets that aren't gold) are in the game.
//     uint8 internal immutable GOODS_COUNT;
//     // Maximum number of swaps allowed in a single player bundle.
//     uint8 internal immutable MAX_SWAPS_PER_BUNDLE;
//     constructor(
//         IGame game,
//         uint8 playerIdx,
//         uint8 playerCount,
//         uint8 assetCount
//     ) AssetMarket(assetCount) {
//         GAME = game;
//         PLAYER_IDX = playerIdx;
//         PLAYER_COUNT = playerCount;
//         ASSET_COUNT = assetCount;
//         GOODS_COUNT = ASSET_COUNT - 1;
//         MAX_SWAPS_PER_BUNDLE = ASSET_COUNT * (ASSET_COUNT - 1);
//     }

//     function checkIfPlayerAboutToWin(PlayerBundle memory bundle) public {
//         for (uint256 player = 0; player < PLAYER_COUNT; i++) {
//             if (player == PLAYER_IDX) {
//                 continue;
//             }

//             // Load reserves from game
//             _storeReserves(GAME.marketState());

//             uint256 totalGoldReserves = 0;

//             for (uint256 i = 0; i < GOODS_COUNT; i++) {
//                 uint8 assetIndex = FIRST_GOOD_IDX + i;

//                 uint256 totalGoldReserves = _sell(
//                     assetIndex,
//                     GOLD_IDX,
//                     GAME.balanceOf(player, assetIndex)
//                 );
//             }

//             uint8 assetIndexMax = 0;
//             uint256 assetAmountMax = 0;

//             for (uint8 i; i < GOODS_COUNT; ++i) {
//                 uint8 assetIndex = FIRST_GOOD_IDX + i;

//                 uint256 assetAmountNew = _quoteSell(
//                     GOLD_IDX,
//                     assetIndex,
//                     totalGoldReserves
//                 );

//                 if (assetAmountNew > assetAmountMax) {
//                     assetAmountMax = assetAmountNew;
//                     assetIndexMax = assetIndex;
//                 }
//             }
//         }
//     }

//     function _getCheapestAssetSimple()
//         internal
//         view
//         returns (uint8 cheapestAssetIdx, uint256 assetAmountMax)
//     {
//         uint8 assetIndexMax = 0;

//         for (uint8 i; i < GOODS_COUNT; ++i) {
//             uint8 assetIndex = FIRST_GOOD_IDX + i;

//             uint256 assetAmountNew = GAME.quoteSell(
//                 GOLD_IDX,
//                 assetIndex,
//                 GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
//             );

//             if (assetAmountNew > assetAmountMax) {
//                 assetAmountMax = assetAmountNew;
//                 assetIndexMax = assetIndex;
//             }
//         }

//         cheapestAssetIdx = assetIndexMax;
//     }

//     function _getCheapestAssetSmart()
//         internal
//         returns (uint8 cheapestAssetIdx, uint256 assetAmountMax)
//     {
//         uint8 assetIndexMax = 0;

//         uint256[] memory tempAssetAmounts = new uint256[](GOODS_COUNT + 1);

//         for (uint8 i; i < GOODS_COUNT; ++i) {
//             // Load reserves from game
//             _storeReserves(GAME.marketState());

//             uint8 assetIndex = FIRST_GOOD_IDX + i;
//             uint256 assetAmountNew;

//             // Sell all the gold you have for equal amount of all assets
//             for (uint8 j; j < GOODS_COUNT; ++j) {
//                 uint8 tempAssetIndex = FIRST_GOOD_IDX + j;

//                 tempAssetAmounts[tempAssetIndex] = _sell(
//                     GOLD_IDX,
//                     tempAssetIndex,
//                     GAME.balanceOf(PLAYER_IDX, GOLD_IDX) / GOODS_COUNT
//                 );
//             }

//             // Sell all the assets you have for gold
//             for (uint8 j; j < GOODS_COUNT; ++j) {
//                 uint8 tempAssetIndex = FIRST_GOOD_IDX + j;

//                 assetAmountNew += _sell(
//                     tempAssetIndex,
//                     assetIndex,
//                     tempAssetAmounts[tempAssetIndex]
//                 );
//             }

//             if (assetAmountNew > assetAmountMax) {
//                 assetAmountMax = assetAmountNew;
//                 assetIndexMax = assetIndex;
//             }
//         }

//         cheapestAssetIdx = assetIndexMax;
//     }

//     function createBundle(
//         uint8 builderIdx
//     ) public virtual override returns (PlayerBundle memory bundle) {
//         // TODO: Add check here that sells everything for 1 asset if this is round 32
//         if (builderIdx % 4 == 0) {
//             require(false, "I have no bundle");
//         } else if (builderIdx % 4 == 1) {
//             bundle = PlayerBundle({swaps: new SwapSell[](1)});
//             bundle.swaps[0] = SwapSell({
//                 fromAssetIdx: GOLD_IDX,
//                 toAssetIdx: FIRST_GOOD_IDX,
//                 fromAmount: GAME.balanceOf(PLAYER_IDX, GOLD_IDX) + 1000
//             });
//         } else if (builderIdx % 4 == 2) {
//             bundle = PlayerBundle({swaps: new SwapSell[](1)});
//             bundle.swaps[0] = SwapSell({
//                 fromAssetIdx: GOLD_IDX,
//                 toAssetIdx: 100,
//                 fromAmount: GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
//             });
//         } else {
//             uint8 first = FIRST_GOOD_IDX;
//             uint8 second = FIRST_GOOD_IDX + 1;

//             uint256 initialFirst = GAME.balanceOf(PLAYER_IDX, first);
//             uint256 initialSecond = GAME.balanceOf(PLAYER_IDX, second);

//             bundle = PlayerBundle({
//                 swaps: new SwapSell[](MAX_SWAPS_PER_BUNDLE)
//             });

//             for (uint256 i; i < bundle.swaps.length; i++) {
//                 bundle.swaps[i] = SwapSell({
//                     fromAssetIdx: i % 2 == 0 ? first : second,
//                     toAssetIdx: i % 2 == 0 ? second : first,
//                     fromAmount: GAME.balanceOf(
//                         PLAYER_IDX,
//                         i % 2 == 0 ? first : second
//                     )
//                 });
//             }

//             require(
//                 initialFirst <= GAME.balanceOf(PLAYER_IDX, first) &&
//                     initialSecond <= GAME.balanceOf(PLAYER_IDX, second),
//                 "Loss"
//             );
//         }
//     }

//     function findMaxInList(
//         int256[] memory list
//     ) internal pure returns (uint256 maxIndex) {
//         int256 max = list[0];
//         for (uint256 i = 1; i < list.length; i++) {
//             if (list[i] > max) {
//                 max = list[i];
//                 maxIndex = i;
//             }
//         }
//     }

//     function sandwichBundleWithGold(
//         uint8 playerIdx,
//         PlayerBundle memory bundle
//     ) internal returns (uint256 goldProfit) {
//         int256[] memory assetAmounts = new int256[](ASSET_COUNT);

//         bytes memory testNull = abi.encode(bundle);
//         bool salmonellaBundle = false;

//         if (testNull.length == 0) {
//             GAME.settleBundle(playerIdx, bundle);
//             return 0;
//         }

//         for (uint256 i; i < bundle.swaps.length; i++) {
//             SwapSell memory swap = bundle.swaps[i];
//             try
//                 GAME.quoteSell(
//                     swap.fromAssetIdx,
//                     swap.toAssetIdx,
//                     swap.fromAmount
//                 )
//             returns (uint256 toAmount) {
//                 assetAmounts[swap.toAssetIdx] += int256(toAmount);
//                 assetAmounts[swap.fromAssetIdx] -= int256(swap.fromAmount);
//             } catch {
//                 salmonellaBundle = true;
//             }
//         }

//         uint8 assetIndexMax = uint8(findMaxInList(assetAmounts));

//         if (salmonellaBundle) {
//             GAME.settleBundle(playerIdx, bundle);
//             return 0;
//         }

//         GAME.sell(
//             GOLD_IDX,
//             assetIndexMax,
//             GAME.balanceOf(PLAYER_IDX, GOLD_IDX)
//         );

//         GAME.settleBundle(playerIdx, bundle);

//         GAME.sell(
//             assetIndexMax,
//             GOLD_IDX,
//             GAME.balanceOf(PLAYER_IDX, assetIndexMax)
//         );
//     }

//     function buildBlock(
//         PlayerBundle[] calldata bundles
//     ) public virtual override returns (uint256 goldBid) {
//         uint256 bidAmount = 0;

//         // 1. Sell everything we have first for gold
//         for (uint8 i; i < GOODS_COUNT; ++i) {
//             GAME.sell(
//                 FIRST_GOOD_IDX + i,
//                 GOLD_IDX,
//                 GAME.balanceOf(PLAYER_IDX, FIRST_GOOD_IDX + i)
//             );
//         }

//         uint256 initialGold = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);

//         // 2. Settle everyone else's bundles with sandwiches
//         for (uint8 playerIdx = 0; playerIdx < bundles.length; ++playerIdx) {
//             if (playerIdx == PLAYER_IDX) {
//                 // Skip our bundle.
//                 continue;
//             }
//             sandwichBundleWithGold(playerIdx, bundles[playerIdx]);
//         }

//         bool chooseSmart;
//         // Check if at the end of the block we can win
//         (
//             uint8 assetIndexMaxSmart,
//             uint256 assetAmountSmart
//         ) = _getCheapestAssetSmart();
//         (
//             uint8 assetIndexMaxSimple,
//             uint256 assetAmountSimple
//         ) = _getCheapestAssetSimple();

//         uint8 assetIndexMax;
//         uint256 assetAmount;

//         console.log("Smart: ", assetAmountSmart);
//         console.log("Simple: ", assetAmountSimple);

//         if (assetAmountSmart >= assetAmountSimple) {
//             assetAmount = assetAmountSmart;
//             assetIndexMax = assetIndexMaxSmart;
//             chooseSmart = true;

//             console.log(
//                 "CHOSE ASSET SMART========================================="
//             );
//             console.log("Profit: ", assetAmountSmart - assetAmountSimple);
//         } else {
//             assetAmount = assetAmountSimple;
//             assetIndexMax = assetIndexMaxSimple;
//             chooseSmart = false;
//             console.log("CHOSE ASSET SIMPLE======================");
//         }

//         // 3. If enough gold to win then bid everything else, and win
//         if (assetAmount >= 64e18) {
//             GAME.buy(GOLD_IDX, assetIndexMax, 64e18);
//             bidAmount = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
//         } else {
//             uint256 totalProfit = GAME.balanceOf(PLAYER_IDX, GOLD_IDX) >
//                 initialGold
//                 ? GAME.balanceOf(PLAYER_IDX, GOLD_IDX) - initialGold
//                 : 0;

//             if (totalProfit == 0) {
//                 bidAmount = 2e14;
//             } else if (GAME.round() == 32) {
//                 GAME.sell(
//                     GOLD_IDX,
//                     assetIndexMax,
//                     (GAME.balanceOf(PLAYER_IDX, GOLD_IDX) * 9) / 10
//                 );
//                 bidAmount = GAME.balanceOf(PLAYER_IDX, GOLD_IDX);
//             } else {
//                 // Bid everything except 1 wei of profit
//                 bidAmount = totalProfit - 1;
//             }
//         }

//         return bidAmount;
//     }
// }
