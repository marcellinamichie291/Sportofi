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
        uint256 sideInFavorScore = uint8(scores_ >> (side << 3));
        uint256 sideAgainstScore = uint8(scores_ >> (sideAgainst_ << 3));

        if (betType_ == uint8(BetType.CORRECT_SCORE))
            return
                (sideAgainstScore << 8) | sideInFavorScore == betData_
                    ? true
                    : false;
        else if (betType_ == uint8(BetType.OVER))
            return sideInFavorScore >= betData_;
        else if (betType_ == uint8(BetType.UNDER))
            return sideInFavorScore <= betData_;
        else if (betType_ == uint8(BetType.WIN))
            return sideInFavorScore > sideAgainstScore;
        else if (betType_ == uint8(BetType.DRAW))
            return sideInFavorScore == sideAgainstScore;

        return false;
    }
}
