// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";

import { SablierV2OpenEnded } from "src/SablierV2OpenEnded.sol";
import { OpenEnded } from "src/types/DataTypes.sol";

import { ERC20Mock } from "./mocks/ERC20Mock.sol";
import { ERC20MissingReturn } from "./mocks/ERC20MissingReturn.sol";
import { Assertions } from "./utils/Assertions.sol";
import { Events } from "./utils/Events.sol";
import { Modifiers } from "./utils/Modifiers.sol";

struct Users {
    address sender;
    address recipient;
}

abstract contract Base_Test is Assertions, Events, Modifiers {
    using SafeCast for uint256;

    /*//////////////////////////////////////////////////////////////////////////
                                     DEFAULTS
    //////////////////////////////////////////////////////////////////////////*/

    uint128 public constant RATE_PER_SECOND = 0.001e18; // 86.4 daily
    uint128 public constant DEPOSIT_AMOUNT = 50_000e18;
    uint40 public immutable ONE_MONTH = 1 days * 30; // "30/360" convention
    uint128 public constant ONE_MONTH_STREAMED_AMOUNT = 2592e18; // 86.4 * 30
    uint128 public constant ONE_MONTH_REFUNDABLE_AMOUNT = DEPOSIT_AMOUNT - ONE_MONTH_STREAMED_AMOUNT;
    uint128 public constant REFUND_AMOUNT = 10_000e18;
    uint40 public immutable WARP_ONE_MONTH;
    uint128 public constant WITHDRAW_AMOUNT = 2500e18;

    Users internal users;

    /*//////////////////////////////////////////////////////////////////////////
                                   TEST CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    ERC20Mock internal dai = new ERC20Mock("Dai stablecoin", "DAI");
    ERC20MissingReturn internal usdt = new ERC20MissingReturn("USDT stablecoin", "USDT", 6);
    SablierV2OpenEnded internal openEnded;

    /*//////////////////////////////////////////////////////////////////////////
                                    CONSTRUCTOR
    //////////////////////////////////////////////////////////////////////////*/

    constructor() {
        WARP_ONE_MONTH = uint40(block.timestamp + ONE_MONTH);
    }

    /*//////////////////////////////////////////////////////////////////////////
                                  SET-UP FUNCTION
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        openEnded = new SablierV2OpenEnded();

        users.sender = createUser("sender");
        users.recipient = createUser("recipient");

        vm.label(address(openEnded), "Open Ended");
        vm.label(address(dai), "DAI");
        vm.label(address(usdt), "USDT");

        vm.startPrank({ msgSender: users.sender });
        dai.approve({ spender: address(openEnded), amount: UINT256_MAX });
        usdt.approve({ spender: address(openEnded), value: UINT256_MAX });
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      HELPERS
    //////////////////////////////////////////////////////////////////////////*/

    function createUser(string memory name) internal returns (address payable) {
        address payable user = payable(makeAddr(name));
        vm.deal({ account: user, newBalance: 100 ether });
        deal({ token: address(dai), to: user, give: 1_000_000e18 });
        deal({ token: address(usdt), to: user, give: 1_000_000e18 });
        return user;
    }

    function normalizeBalance(uint256 streamId) internal view returns (uint256) {
        return normalizeTransferAmount(streamId, openEnded.getBalance(streamId));
    }

    function normalizeTransferAmount(
        uint256 streamId,
        uint128 amount
    )
        internal
        view
        returns (uint128 normalizedAmount)
    {
        // Retrieve the asset's decimals from storage.
        uint8 assetDecimals = openEnded.getAssetDecimals(streamId);

        // Return the original amount if it's already in the standard 18-decimal format.
        if (assetDecimals == 18) {
            return amount;
        }

        bool isGreaterThan18 = assetDecimals > 18;

        uint8 normalizationFactor = isGreaterThan18 ? assetDecimals - 18 : 18 - assetDecimals;

        normalizedAmount = isGreaterThan18
            ? (amount * (10 ** normalizationFactor)).toUint128()
            : (amount / (10 ** normalizationFactor)).toUint128();
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    CALL EXPECTS
    //////////////////////////////////////////////////////////////////////////*/

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(address to, uint256 amount) internal {
        vm.expectCall({ callee: address(dai), data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transfer}.
    function expectCallToTransfer(IERC20 asset, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transfer, (to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(dai), data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }

    /// @dev Expects a call to {IERC20.transferFrom}.
    function expectCallToTransferFrom(IERC20 asset, address from, address to, uint256 amount) internal {
        vm.expectCall({ callee: address(asset), data: abi.encodeCall(IERC20.transferFrom, (from, to, amount)) });
    }
}
