//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Vm.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../Bet2Win.sol";
import "../Treasury.sol";
import "../Governance.sol";

import "./TestHelper.sol";
import {IGToken, GToken, IPMToken, PMToken} from "./ERC20.sol";
import {AggregatorV3Interface, PriceFeed} from "./PriceFeed.sol";
import {ERC20PermitHelper, Bet2WinPermitHelper} from "./SigUtils.sol";

import "../interfaces/IBet2Win.sol";
import "../interfaces/ITreasury.sol";
import "../interfaces/IGovernance.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/draft-IERC20PermitUpgradeable.sol";

contract Bet2WinTest is Test {
    address admin;
    address gambler;

    uint256 adminPk;
    uint256 gamblerPk;

    IBet2Win house;
    ITreasury treasury;
    IGovernance governance;

    IGToken gToken;
    IPMToken pmToken;

    ERC20PermitHelper tokenSigUtil;
    Bet2WinPermitHelper houseSigUtil;

    CheatCodes cheats = CheatCodes(HEVM_ADDRESS);

    constructor() {
        adminPk = 0xA11CE;
        gamblerPk = 0xB0B;

        admin = vm.addr(adminPk);
        gambler = vm.addr(gamblerPk);

        console.logAddress(msg.sender);
        console.logAddress(admin);

        vm.startPrank(admin, admin);

        gToken = IGToken(address(new GToken("SPORTOFI", "SPORT")));
        governance = IGovernance(address(new GovernanceUpgradeable()));
        treasury = ITreasury(address(new TreasuryUpgradeable(governance)));

        house = IBet2Win(
            address(
                new Bet2WinUpgradeable(
                    governance,
                    treasury,
                    IERC20Upgradeable(address(gToken)),
                    AggregatorV3Interface(address(new PriceFeed()))
                )
            )
        );
        houseSigUtil = new Bet2WinPermitHelper(house.DOMAIN_SEPARATOR());

        vm.stopPrank();

        pmToken = IPMToken(address(new PMToken("PaymentToken", "PMT")));
        tokenSigUtil = new ERC20PermitHelper(pmToken.DOMAIN_SEPARATOR());
    }

    function setUp() public {
        hoax(gambler, 1_000_000 ether);
        pmToken.mint(gambler, 1_000_000);

        // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called, and the tx.origin to be the second input
        vm.startPrank(admin, admin);

        gToken.mint(address(house), 1_000_000);
        assertTrue(governance.hasRole(Roles.TREASURER_ROLE, admin));
        IERC20Upgradeable[] memory arr = new IERC20Upgradeable[](2);
        arr[0] = IERC20Upgradeable(address(0));
        arr[1] = IERC20Upgradeable(address(pmToken));
        treasury.updatePayments(arr);
        assertTrue(governance.hasRole(Roles.OPERATOR_ROLE, admin));
        governance.grantRole(Roles.SIGNER_ROLE, admin);

        vm.stopPrank();
    }

    function testValidBetNativePayment() public {
        uint96 amount = 25 ether;
        address payment = address(0);
        uint256 deadline = block.timestamp + 5 minutes;
        (uint256 betId, , bytes memory signature) = __createValidBetOrder({
            gameId: 0,
            matchId: 1,
            odd: 345,
            settleStatus: 6,
            side: 7,
            amount: amount,
            deadline: deadline,
            paymentToken: payment
        });

        vm.prank(gambler, gambler);
        house.placeBet{value: amount}(
            betId,
            amount,
            0,
            deadline,
            0,
            0,
            0,
            IERC20Upgradeable(payment),
            signature
        );

        assertEq(address(treasury).balance, amount);
    }

    function testValidBetERC20Payment() public {
        uint96 amount = 25 ether;
        uint256 deadline = block.timestamp + 5 minutes;
        (uint8 v, bytes32 r, bytes32 s) = __signPermit(amount, deadline);
        (uint256 betId, , bytes memory signature) = __createValidBetOrder({
            gameId: 0,
            matchId: 1,
            odd: 345,
            settleStatus: 6,
            side: 7,
            amount: amount,
            deadline: deadline,
            paymentToken: address(pmToken)
        });

        vm.prank(gambler, gambler);
        house.placeBet{value: amount}(
            betId,
            amount,
            deadline,
            deadline,
            v,
            r,
            s,
            IERC20Upgradeable(address(pmToken)),
            signature
        );

        assertEq(pmToken.balanceOf(address(treasury)), amount);
    }

    function __signPermit(uint256 amount, uint256 deadline)
        private
        returns (
            uint8 v,
            bytes32 r,
            bytes32 s
        )
    {
        {
            (v, r, s) = vm.sign(
                gamblerPk,
                tokenSigUtil.getTypedDataHash(
                    gambler,
                    address(house),
                    amount,
                    pmToken.nonces(gambler),
                    deadline
                )
            );
        }
    }

    function __createValidBetOrder(
        uint256 gameId,
        uint256 matchId,
        uint256 odd,
        uint256 settleStatus,
        uint256 side,
        uint256 amount,
        uint256 deadline,
        address paymentToken
    )
        private
        returns (
            uint256 betId,
            bytes32 digest,
            bytes memory signature
        )
    {
        betId = house.betIdOf(gameId, matchId, odd, settleStatus, side);

        digest = houseSigUtil.getTypedDataHash(
            gambler,
            betId,
            amount,
            paymentToken,
            deadline,
            house.nonces(gambler)
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(adminPk, digest);
        signature = abi.encodePacked(r, s, v);
    }
}
