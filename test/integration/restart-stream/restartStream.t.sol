// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import { ISablierV2OpenEnded } from "src/interfaces/ISablierV2OpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";
import { OpenEnded } from "src/types/DataTypes.sol";

import { Integration_Test } from "../Integration.t.sol";

contract RestartStream_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        openEnded.cancel({ streamId: defaultStreamId });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(ISablierV2OpenEnded.restartStream, (defaultStreamId, AMOUNT_PER_SECOND));
        _test_RevertWhen_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        _test_RevertGiven_Null();
        openEnded.restartStream({ streamId: nullStreamId, amountPerSecond: AMOUNT_PER_SECOND });
    }

    function test_RevertGiven_NotCanceled() external whenNotDelegateCalled givenNotNull {
        uint256 streamId = createDefaultStream();
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2OpenEnded_StreamNotCanceled.selector, streamId));
        openEnded.restartStream({ streamId: streamId, amountPerSecond: AMOUNT_PER_SECOND });
    }

    function test_RevertWhen_CallerUnauthorized_Recipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerUnauthorized
    {
        changePrank({ msgSender: users.recipient });
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, defaultStreamId, users.recipient)
        );
        openEnded.restartStream({ streamId: defaultStreamId, amountPerSecond: AMOUNT_PER_SECOND });
    }

    function test_RevertWhen_CallerUnauthorized_MaliciousThirdParty(address maliciousThirdParty)
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerUnauthorized
    {
        vm.assume(maliciousThirdParty != users.sender && maliciousThirdParty != users.recipient);
        changePrank({ msgSender: maliciousThirdParty });
        vm.expectRevert(
            abi.encodeWithSelector(
                Errors.SablierV2OpenEnded_Unauthorized.selector, defaultStreamId, maliciousThirdParty
            )
        );
        openEnded.restartStream({ streamId: defaultStreamId, amountPerSecond: AMOUNT_PER_SECOND });
    }

    function test_RevertWhen_AmountPerSecondZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerAuthorized
    {
        vm.expectRevert(Errors.SablierV2OpenEnded_AmountPerSecondZero.selector);
        openEnded.restartStream({ streamId: defaultStreamId, amountPerSecond: 0 });
    }

    function test_RestartStream()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerAuthorized
        whenAmountPerSecondNonZero
    {
        openEnded.restartStream({ streamId: defaultStreamId, amountPerSecond: AMOUNT_PER_SECOND });

        bool isCanceled = openEnded.isCanceled(defaultStreamId);
        assertFalse(isCanceled);

        uint128 actualAmountPerSecond = openEnded.getAmountPerSecond(defaultStreamId);
        assertEq(actualAmountPerSecond, AMOUNT_PER_SECOND, "amountPerSecond");

        uint40 actualLastTimeUpdate = openEnded.getLastTimeUpdate(defaultStreamId);
        assertEq(actualLastTimeUpdate, block.timestamp, "lastTimeUpdate");
    }
}
