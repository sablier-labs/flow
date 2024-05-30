// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../../Integration.t.sol";

contract Restart_Integration_Concrete_Test is Integration_Test {
    function setUp() public override {
        Integration_Test.setUp();

        flow.pause({ streamId: defaultStreamId });
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(flow.restart, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_DelegateCall(callData);
    }

    function test_RevertGiven_Null() external whenNotDelegateCalled {
        bytes memory callData = abi.encodeCall(flow.restart, (nullStreamId, RATE_PER_SECOND));
        expectRevert_Null(callData);
    }

    function test_RevertWhen_CallerRecipient()
        external
        whenNotDelegateCalled
        givenNotNull
        givenPaused
        whenCallerIsNotSender
    {
        bytes memory callData = abi.encodeCall(flow.restart, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_CallerRecipient(callData);
    }

    function test_RevertWhen_CallerMaliciousThirdParty()
        external
        whenNotDelegateCalled
        givenNotNull
        givenPaused
        whenCallerIsNotSender
    {
        bytes memory callData = abi.encodeCall(flow.restart, (defaultStreamId, RATE_PER_SECOND));
        expectRevert_CallerMaliciousThirdParty(callData);
    }

    function test_RevertGiven_NotPaused() external whenNotDelegateCalled givenNotNull {
        uint256 streamId = createDefaultStream();
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierFlow_StreamNotPaused.selector, streamId));
        flow.restart({ streamId: streamId, ratePerSecond: RATE_PER_SECOND });
    }

    function test_RevertWhen_RatePerSecondZero()
        external
        whenNotDelegateCalled
        givenNotNull
        givenPaused
        whenCallerIsSender
    {
        vm.expectRevert(Errors.SablierFlow_RatePerSecondZero.selector);
        flow.restart({ streamId: defaultStreamId, ratePerSecond: 0 });
    }

    function test_Restart()
        external
        whenNotDelegateCalled
        givenNotNull
        givenPaused
        whenCallerIsSender
        whenRatePerSecondIsNotZero
    {
        vm.expectEmit({ emitter: address(flow) });
        emit RestartFlowStream({
            streamId: defaultStreamId,
            sender: users.sender,
            asset: dai,
            ratePerSecond: RATE_PER_SECOND
        });
        vm.expectEmit({ emitter: address(flow) });
        emit MetadataUpdate({ _tokenId: defaultStreamId });

        flow.restart({ streamId: defaultStreamId, ratePerSecond: RATE_PER_SECOND });

        bool isPaused = flow.isPaused(defaultStreamId);
        assertFalse(isPaused);

        uint128 actualRatePerSecond = flow.getRatePerSecond(defaultStreamId);
        assertEq(actualRatePerSecond, RATE_PER_SECOND, "ratePerSecond");

        uint40 actualLastTimeUpdate = flow.getLastTimeUpdate(defaultStreamId);
        assertEq(actualLastTimeUpdate, block.timestamp, "lastTimeUpdate");
    }
}