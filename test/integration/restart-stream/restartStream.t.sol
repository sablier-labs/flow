// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { ISablierOpenEnded } from "src/interfaces/ISablierOpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract RestartStream_Integration_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        openEnded.cancel({ streamId: defaultStreamId });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData =
            abi.encodeCall(ISablierOpenEnded.restartStream, (defaultStreamId, defaults.RATE_PER_SECOND()));
        expectRevertDueToDelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        uint128 ratePerSecond = defaults.RATE_PER_SECOND();

        expectRevertNull();
        openEnded.restartStream({ streamId: nullStreamId, ratePerSecond: ratePerSecond });
    }

    function test_RevertGiven_NotCanceled() external whenNotDelegateCalled givenNotNull {
        uint256 streamId = createDefaultStream();
        uint128 ratePerSecond = defaults.RATE_PER_SECOND();

        vm.expectRevert(abi.encodeWithSelector(Errors.SablierOpenEnded_StreamNotCanceled.selector, streamId));
        openEnded.restartStream({ streamId: streamId, ratePerSecond: ratePerSecond });
    }

    function test_RevertWhen_CallerUnauthorized_Recipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.recipient });
        uint128 ratePerSecond = defaults.RATE_PER_SECOND();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierOpenEnded_Unauthorized.selector, defaultStreamId, users.recipient)
        );
        openEnded.restartStream({ streamId: defaultStreamId, ratePerSecond: ratePerSecond });
    }

    function test_RevertWhen_CallerUnauthorized_MaliciousThirdParty()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.eve });
        uint128 ratePerSecond = defaults.RATE_PER_SECOND();

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierOpenEnded_Unauthorized.selector, defaultStreamId, users.eve)
        );
        openEnded.restartStream({ streamId: defaultStreamId, ratePerSecond: ratePerSecond });
    }

    function test_RevertWhen_ratePerSecondZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerAuthorized
    {
        vm.expectRevert(Errors.SablierOpenEnded_RatePerSecondZero.selector);
        openEnded.restartStream({ streamId: defaultStreamId, ratePerSecond: 0 });
    }

    function test_RestartStream()
        external
        whenNotDelegateCalled
        givenNotNull
        givenCanceled
        whenCallerAuthorized
        whenRatePerSecondNonZero
    {
        openEnded.restartStream({ streamId: defaultStreamId, ratePerSecond: defaults.RATE_PER_SECOND() });

        bool isCanceled = openEnded.isCanceled(defaultStreamId);
        assertFalse(isCanceled);

        uint128 actualratePerSecond = openEnded.getRatePerSecond(defaultStreamId);
        assertEq(actualratePerSecond, defaults.RATE_PER_SECOND(), "ratePerSecond");

        uint40 actualLastTimeUpdate = openEnded.getLastTimeUpdate(defaultStreamId);
        assertEq(actualLastTimeUpdate, block.timestamp, "lastTimeUpdate");
    }
}
