// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library BetLogic {
    enum BetType {
        WIN,
        DRAW,
        OVER,
        UNDER,
        CORRECT_SCORE
    }

    function isValidClaim(
        uint256 side,
        uint256 sideAgainst_,
        uint256 betType_,
        uint256 betData_,
        uint256 scores_
    ) internal pure returns (bool) {
        uint256 sideInFavorResult = (scores_ >> (side << 3)) & 0xff;
        uint256 sideAgainstResult = (scores_ >> (sideAgainst_ << 3)) & 0xff;

        uint256 sideInFavorScore = (betData_ >> (side << 3)) & 0xff;
        uint256 sideAgainstScore = (betData_ >> (sideAgainst_ << 3)) & 0xff;

        if (betType_ == uint8(BetType.CORRECT_SCORE))
            return
                sideAgainstScore == sideAgainstResult &&
                sideInFavorScore == sideInFavorResult;
        if (betType_ == uint8(BetType.OVER))
            return sideInFavorResult + sideAgainstResult >= sideInFavorScore;
        if (betType_ == uint8(BetType.UNDER))
            return sideInFavorResult + sideAgainstResult < sideInFavorScore;
        if (betType_ == uint8(BetType.WIN))
            return sideInFavorResult > sideAgainstResult;
        if (betType_ == uint8(BetType.DRAW))
            return sideInFavorResult == sideAgainstResult;

        return false;
    }
}
