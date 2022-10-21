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
        uint256 sideInFavorScore = (scores_ >> (side << 3)) & ~uint8(0);
        uint256 sideAgainstScore = (scores_ >> (sideAgainst_ << 3)) & ~uint8(0);

        uint256 sideInFavorResult = (betData_ >> (side << 3)) & ~uint8(0);
        uint256 sideAgainstResult = (betData_ >> (sideAgainst_ << 3)) &
            ~uint8(0);

        if (betType_ == uint8(BetType.CORRECT_SCORE))
            return
                sideAgainstScore == sideAgainstResult &&
                sideInFavorScore == sideInFavorResult;
        else if (betType_ == uint8(BetType.OVER))
            return sideInFavorResult >= sideInFavorScore;
        else if (betType_ == uint8(BetType.UNDER))
            return sideInFavorResult <= sideInFavorScore;
        else if (betType_ == uint8(BetType.WIN))
            return sideInFavorScore > sideAgainstScore;
        else if (betType_ == uint8(BetType.DRAW))
            return sideInFavorResult == sideAgainstResult;

        return false;
    }
}
