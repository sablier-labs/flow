// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.22;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { ISablierV2OpenEnded } from "src/interfaces/ISablierV2OpenEnded.sol";
import { Errors } from "src/libraries/Errors.sol";

import { Integration_Test } from "../Integration.t.sol";

contract CancelMultiple_Integration_Concrete_Test is Integration_Test {
    uint256[] internal testStreamIds;

    function setUp() public override {
        Integration_Test.setUp();

        vm.warp({ newTimestamp: WARP_ONE_MONTH });

        testStreamIds = new uint256[](2);
        testStreamIds[0] = defaultStreamId;
        testStreamIds[1] = createDefaultStream();
    }

    function test_RevertWhen_DelegateCall() external {
        bytes memory callData = abi.encodeCall(ISablierV2OpenEnded.cancelMultiple, (testStreamIds));
        _test_RevertWhen_DelegateCall(callData);
    }

    function test_CancelMultiple_ArrayCountZero() external whenNotDelegateCalled {
        uint256[] memory streamIds = new uint256[](0);
        openEnded.cancelMultiple(streamIds);
    }

    function test_RevertGiven_OnlyNull() external whenNotDelegateCalled whenArrayCountNotZero {
        testStreamIds[0] = nullStreamId;
        testStreamIds[1] = nullStreamId;
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2OpenEnded_Null.selector, nullStreamId));
        openEnded.cancelMultiple({ streamIds: testStreamIds });
    }

    function test_RevertGiven_SomeNull() external whenNotDelegateCalled whenArrayCountNotZero {
        testStreamIds[0] = nullStreamId;
        vm.expectRevert(abi.encodeWithSelector(Errors.SablierV2OpenEnded_Null.selector, nullStreamId));
        openEnded.cancelMultiple({ streamIds: testStreamIds });
    }

    function test_RevertWhen_CallerUnauthorizedAllStreams_MaliciousThirdParty()
        external
        whenNotDelegateCalled
        whenArrayCountNotZero
        givenNotNull
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.eve });

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, testStreamIds[0], users.eve)
        );
        openEnded.cancelMultiple(testStreamIds);
    }

    function test_RevertWhen_CallerUnauthorizedAllStreams_Recipient()
        external
        whenNotDelegateCalled
        whenArrayCountNotZero
        givenNotNull
        whenCallerUnauthorized
    {
        resetPrank({ msgSender: users.recipient });

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, testStreamIds[0], users.recipient)
        );
        openEnded.cancelMultiple(testStreamIds);
    }

    function test_RevertWhen_CallerUnauthorizedSomeStreams_MaliciousThirdParty()
        external
        whenNotDelegateCalled
        whenArrayCountNotZero
        givenNotNull
        whenCallerUnauthorized
    {
        uint256 eveStreamId = openEnded.create({
            sender: users.eve,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            asset: dai
        });

        resetPrank({ msgSender: users.eve });
        testStreamIds[0] = eveStreamId;
        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, testStreamIds[1], users.eve)
        );
        openEnded.cancelMultiple(testStreamIds);
    }

    function test_RevertWhen_CallerUnauthorizedSomeStreams_Recipient()
        external
        whenNotDelegateCalled
        whenArrayCountNotZero
        givenNotNull
        whenCallerUnauthorized
    {
        testStreamIds[0] = openEnded.create({
            sender: users.recipient,
            recipient: users.recipient,
            ratePerSecond: RATE_PER_SECOND,
            asset: dai
        });

        resetPrank({ msgSender: users.recipient });

        vm.expectRevert(
            abi.encodeWithSelector(Errors.SablierV2OpenEnded_Unauthorized.selector, testStreamIds[1], users.recipient)
        );
        openEnded.cancelMultiple(testStreamIds);
    }

    function test_CancelMultiple() external {
        openEnded.cancelMultiple(testStreamIds);

        assertTrue(openEnded.isCanceled(testStreamIds[0]));
        assertTrue(openEnded.isCanceled(testStreamIds[1]));

        assertEq(openEnded.getRatePerSecond(testStreamIds[0]), 0);
        assertEq(openEnded.getRatePerSecond(testStreamIds[1]), 0);
    }
}
