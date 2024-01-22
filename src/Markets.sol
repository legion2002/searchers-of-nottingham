pragma solidity ^0.8;

import { UD60x18, ZERO, UNIT, convert, sqrt } from 'prb-math/UD60x18.sol';

UD60x18 constant MIN_LIQUIDITY_PER_RESERVE = UD60x18.wrap(1e4);
UD60x18 constant MAX_LIQUIDITY_PER_RESERVE = UD60x18.wrap(1e32);
UD60x18 constant MIN_SQRT_K = UD60x18.wrap(1e2);

function fromWei(uint256 weiAmount) pure returns (UD60x18 tokens) {
    // All tokens are 18 decimals so it's identical bit representation to UD60x18.
    return UD60x18.wrap(weiAmount);
}

function toWei(UD60x18 tokens) pure returns (uint256 w) {
    // All tokens are 18 decimals so it's identical bit representation to UD60x18.
    return UD60x18.unwrap(tokens);
}

event K(uint256 x, uint256 y);

// Computes the sqrt product of all the reserves.
function calcSqrtK(UD60x18[] memory reserves) pure returns (UD60x18 k_) {
    k_ = reserves[0];
    bool rooted;
    for (uint256 i = 1; i < reserves.length; ++i) {
        if (rooted) {
            k_ = k_ * sqrt(reserves[i]);
        } else if (UD60x18.unwrap(reserves[i]) > 1e32) {
            rooted = true;
            k_ = sqrt(k_) * sqrt(reserves[i]);
        } else {
            k_ = k_ * reserves[i];
        }
    }
    return rooted ? k_ : sqrt(k_);
}

// Computes the product of all the reserves except for the one at index `omitIdx`.
// function calcKWithout(UD60x18[] memory reserves, uint8 omitIdx)
//     pure returns (UD60x18 k_)
// {
//     k_ = UNIT;
//     for (uint256 i = 0; i < reserves.length; ++i) {
//         if (i != omitIdx) {
//             k_ = k_ * reserves[i];
//         }
//     }
// }

function nthRoot(UD60x18 x, uint256 n) pure returns (UD60x18 r) {
    if (n == 0) return UNIT;
    if (n == 1) return x;
    return UD60x18.wrap(2e18).pow(x.log2() / convert(n));
}

// A multidimensional virtual AMM for 18-decimal asset tokens.
abstract contract AssetMarket {

    error MinLiquidityError();
    error MaxLiquidityError();
    error InsufficientLiquidityError();
    error InvalidAssetError();
    error MinKError();
    error PrecisionError();

    uint8 public immutable ASSET_COUNT;
    mapping (uint8 => UD60x18) private _reserves;

    constructor(uint8 assetCount) {
        assert(assetCount <= type(uint8).max);
        ASSET_COUNT = uint8(assetCount);
    }

    function _init(uint256[] memory initialReserveAmounts) internal {
        assert(initialReserveAmounts.length == ASSET_COUNT);
        UD60x18[] memory reserves;
        // UD60x18 and 18-decimal tokens have identical bit representations so this is OK.
        assembly ("memory-safe") { reserves := initialReserveAmounts }
        for (uint256 i; i < reserves.length; ++i) {
            if (reserves[i] < MIN_LIQUIDITY_PER_RESERVE) revert MinLiquidityError();
            if (reserves[i] > MAX_LIQUIDITY_PER_RESERVE) revert MaxLiquidityError();
        }
        {
            UD60x18 k = calcSqrtK(reserves);
            if (k < MIN_SQRT_K) revert MinKError();
        }
        _storeReserves(reserves);
    }

    function _buy(uint8 fromIdx, uint8 toIdx, uint256 toAmt)
        internal returns (uint256 fromAmt)
    {
        if (fromIdx >= ASSET_COUNT || toIdx >= ASSET_COUNT) revert InvalidAssetError();
        if (fromIdx == toIdx) return toAmt;
        UD60x18[] memory reserves = _loadReserves();
        UD60x18 toAmt_ = fromWei(toAmt);
        UD60x18 fromAmt_ = _quoteBuyFromReserves(reserves[fromIdx], reserves[toIdx], toAmt_);
        reserves[fromIdx] = reserves[fromIdx] + fromAmt_;
        reserves[toIdx] = reserves[toIdx] - toAmt_;
        _reserves[fromIdx] = reserves[fromIdx];
        _reserves[toIdx] = reserves[toIdx];
        return toWei(fromAmt_);
    }

    function _sell(uint8 fromIdx, uint8 toIdx, uint256 fromAmt)
        internal returns (uint256 toAmt)
    {
        if (fromIdx >= ASSET_COUNT || toIdx >= ASSET_COUNT) revert InvalidAssetError();
        if (fromIdx == toIdx) return fromAmt;
        UD60x18[] memory reserves = _loadReserves();
        UD60x18 fromAmt_ = fromWei(fromAmt);
        UD60x18 toAmt_ = _quoteSellFromReserves(reserves[fromIdx], reserves[toIdx], fromAmt_);
        reserves[fromIdx] = reserves[fromIdx] + fromAmt_;
        reserves[toIdx] = reserves[toIdx] - toAmt_;
        _reserves[fromIdx] = reserves[fromIdx];
        _reserves[toIdx] = reserves[toIdx];
        return toWei(toAmt_);
    }

    function _getReserve(uint8 idx) internal view returns (uint256 weiReserve) {
        return toWei(_reserves[idx]);
    }

    function _k() internal view returns (uint256) {
        // Externally, k should be treated as a unitless invariant.
        return toWei(calcSqrtK(_loadReserves()));
    }

    function _getRate(uint8 fromIdx, uint8 toIdx) internal view returns (uint256 toRate) {
        if (fromIdx == toIdx) return 1e18;
        return toWei(_reserves[toIdx] / _reserves[fromIdx]);
    }

    function _quoteBuy(uint8 fromIdx, uint8 toIdx, uint256 toAmt)
        internal view returns (uint256 fromAmt)
    {
        if (fromIdx >= ASSET_COUNT || toIdx >= ASSET_COUNT) revert InvalidAssetError();
        if (fromIdx == toIdx) return toAmt;
        UD60x18[] memory reserves = _loadReserves();
        UD60x18 toAmt_ = fromWei(toAmt);
        UD60x18 fromAmt_ = _quoteBuyFromReserves(reserves[fromIdx], reserves[toIdx], toAmt_);
        return toWei(fromAmt_);
    }

    function _quoteSell(uint8 fromIdx, uint8 toIdx, uint256 fromAmt)
        internal view returns (uint256 toAmt)
    {
        if (fromIdx >= ASSET_COUNT || toIdx >= ASSET_COUNT) revert InvalidAssetError();
        if (fromIdx == toIdx) return fromAmt;
        UD60x18[] memory reserves = _loadReserves();
        UD60x18 fromAmt_ = fromWei(fromAmt);
        UD60x18 toAmt_ = _quoteSellFromReserves(reserves[fromIdx], reserves[toIdx], fromAmt_);
        return toWei(toAmt_);
    }

    function _quoteBuyFromReserves(UD60x18 fromReserve, UD60x18 toReserve, UD60x18 toAmt)
        private pure returns (UD60x18 fromAmt)
    {
        if (toAmt == ZERO) return ZERO;
        if (toAmt >= toReserve) revert InsufficientLiquidityError();
        if (toReserve - toAmt < MIN_LIQUIDITY_PER_RESERVE) revert MinLiquidityError();
        fromAmt = (toAmt * fromReserve) / (toReserve - toAmt);
        if (fromReserve + fromAmt > MAX_LIQUIDITY_PER_RESERVE) revert MaxLiquidityError();
        if (fromAmt == ZERO || fromAmt < toAmt * fromReserve / toReserve) revert PrecisionError();
    }

    function _quoteSellFromReserves(UD60x18 fromReserve, UD60x18 toReserve, UD60x18 fromAmt)
        private pure returns (UD60x18 toAmt)
    {
        if (fromAmt == ZERO) return ZERO;
        if (fromReserve + fromAmt > MAX_LIQUIDITY_PER_RESERVE) revert MaxLiquidityError();
        toAmt = (fromAmt * toReserve) / (fromReserve + fromAmt);
        if (toReserve - toAmt < MIN_LIQUIDITY_PER_RESERVE) revert MinLiquidityError();
    }

    function _storeReserves(UD60x18[] memory reserves) internal {
        for (uint8 i; i < reserves.length; ++i) {
            _reserves[i] = reserves[i];
        }
    }

    function _loadReserves() internal view returns (UD60x18[] memory reserves) {
        reserves = new UD60x18[](ASSET_COUNT);
        for (uint8 i; i < ASSET_COUNT; ++i) {
            reserves[i] = _reserves[i];
        }
    }
}

// // A multi-dimensional, constant product, virtual AMM for blocks. Each asset/index represents
// // a pool of tokens each respective builder can buy to build a block.
// // Rather than buying one "asset" in exchange for one other, buying one asset results
// // in selling a related amount of *every other* asset at once.
// library SLibBlockMarket {
//     struct Storage {
//         UD60x18[] reserves;
//     }

//     bytes32 private constant STORAGE_SLOT = keccak256('SLibBlockMarket::Storage');
//     UD60x18 private constant MIN_LIQUIDITY = UNIT;
//     uint16 internal constant BPS_100_PCT = 1e4;

//     error InvalidBpsError(uint16 bps);

//     function init(uint8 count, uint256 initialReserveAmount) internal {
//         assert(count != 0);
//         UD60x18[] memory reserves = new UD60x18[](count);
//         UD60x18 initialReserveAmount_ = fromWei(initialReserveAmount);
//         for (uint8 i; i < count; ++i) {
//             reserves[i] = initialReserveAmount_;
//         }
//         if (calcK(reserves) < MIN_LIQUIDITY) revert MinLiquidityError();
//         _getStorage().reserves = reserves;
//     }

//     function buyFrac(uint8 idx, uint16 bps) internal returns (uint256 weiCost) {
//         if (bps >= BPS_100_PCT) revert InvalidBpsError(bps);
//         UD60x18[] memory reserves = _getStorage().reserves;
//         UD60x18 buyAmt = reserves[idx] * fromWei(bps * 1e18 / BPS_100_PCT);
//         weiCost = toWei(_calcCostDestructive(reserves, idx, buyAmt));
//         _getStorage().reserves = reserves;
//     }

//     function buy(uint8 idx, uint256 amt) internal returns (uint256 weiCost) {
//         UD60x18[] memory reserves = _getStorage().reserves;
//         weiCost = toWei(_calcCostDestructive(reserves, idx, fromWei(amt)));
//         _getStorage().reserves = reserves;
//     }

//     function quoteBuyFrac(uint8 idx, uint16 bps) internal returns (uint256 weiCost) {
//         if (bps >= BPS_100_PCT) revert InvalidBpsError(bps);
//         UD60x18[] memory reserves = _getStorage().reserves;
//         UD60x18 buyAmt = reserves[idx] * fromWei(bps * 1e18 / BPS_100_PCT);
//         weiCost = toWei(_calcCostDestructive(reserves, idx, buyAmt));
//     }

//     function quoteBuy(uint8 idx, uint256 amt)
//         internal view returns (uint256 weiCost)
//     {
//         UD60x18[] memory reserves = _getStorage().reserves;
//         if (reserves[idx] <= buyAmount) return type(uint256).max;
//         weiCost = toWei(_calcCostDestructive(reserves, idx, fromWei(amt)));
//     }
   
//     function rate(uint8 idx) internal view returns (uint256 weiCost) {
//         UD60x18[] memory reserves = _getStorage().reserves;
//         return toWei(
//             nthRoot(calcKWithout(reserves, idx), reserves.length - 1)
//                 / reserves[idx]
//         );
//     }

//     function count() internal view returns (uint8 count_) {
//         return uint8(_getStorage().reserves.length);
//     }

//     function reserve(uint8 idx) internal view returns (uint256 weiReserve) {
//         UD60x18[] memory reserves = _getStorage().reserves;
//         weiReserve = toWei(reserves[idx]);
//     }

//     function k() internal view returns (uint256) {
//         // Externally, k should be treated as a unitless invariant.
//         return toWei(calcK(_getStorage().reserves));
//     }

//     // Calculate the cost of buying a unit of reserve at `idx` and update
//     // the reserves with the result of the purchase in memory (not storage).
//     function _calcCostDestructive(UD60x18[] memory reserves, uint8 idx)
//         private pure returns (UD60x18 cost)
//     {
//         uint8 nr = uint8(reserves.length);
//         UD60x18 q = _quoteOut(reserves[idx], UNIT, nr);
//         reserves[idx] -= UNIT;
//         // Cost is the sum of the resulting increase in every other reserve
//         // after scaling by `q`.
//         for (uint8 i; i < nr; ++i) {
//             if (i != idx) {
//                 UD60x18 r = reserves[i];
//                 cost += (reserves[i] *= q) - r;
//             }
//         }    
//         // Reserves should always increase with nonzero buys.
//         assert(cost > ZERO);
//     }

//     // Compute `q`, which is the scaling factor to apply to all other reserves
//     // to satisfy the constant product invariant after buying `rOut` qty from reserve `r`.
//     function _quoteOut(UD60x18 r, UD60x18 rOut, uint8 nr)
//         private pure returns (UD60x18 q)
//     {
//         assert(nr > 1);
//         if (rOut == 0) return ZERO;
//         if (r <= rOut) revert InsufficientLiquidityError();
//         // k = (r - rOut) * ∏(otherReserves) * q'; wantAmount >= 1, q' >= 1
//         // r * ∏(otherReserves) = (r - rOut) * ∏(otherReserves) * q'
//         // r / (r - rOut) = q'
//         q = r / (r - rOut);
//         // The scaling factor is applied to every other reserve so we need the `n-1`th root.
//         q = nthRoot(q, nr - 1);
//         // Reserves should always be scaled up with nonzero buys.
//         assert(q > UNIT);
//     }

//     function _getStorage() private pure returns (Storage storage stor) {
//         uint256 slot = uint256(STORAGE_SLOT);
//         assembly ("memory-safe") { stor := slot }
//     }
// }