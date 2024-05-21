// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

abstract contract Modifiers {
    /*//////////////////////////////////////////////////////////////////////////
                                       COMMON
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenBalanceNotZero() {
        _;
    }

    modifier givenBalanceZero() {
        _;
    }

    modifier givenNotPaused() {
        _;
    }

    modifier givenNotNull() {
        _;
    }

    modifier givenRemainingAmountZero() {
        _;
    }

    modifier givenRemainingAmountNotZero() {
        _;
    }

    modifier whenCallerIsTheSender() {
        _;
    }

    modifier whenBrokerAddressIsNotZero() {
        _;
    }

    modifier whenBrokerFeeNotGreaterThanMaxFee() {
        _;
    }

    modifier whenCallerIsNotTheSender() {
        _;
    }

    modifier whenNotDelegateCalled() {
        _;
    }

    modifier whenRatePerSecondIsNotZero() {
        _;
    }

    modifier whenSenderIsNotZeroAddress() {
        _;
    }

    modifier whenTokenDecimalIsNotZero() {
        _;
    }

    modifier whenTokenDoesNotMissERC20Return() {
        _;
    }

    modifier whenTotalAmountIsNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                              ADJUST-AMOUNT-PER-SECOND
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenRatePerSecondNotDifferent() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       PAUSE
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenRefundableAmountNotZero() {
        _;
    }

    modifier givenWithdrawableAmountNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenAssetContract() {
        _;
    }

    modifier whenRecipientNonZeroAddress() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenDepositAmountNonZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                 REFUND-FROM-STREAM
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenNoOverrefund() {
        _;
    }

    modifier whenRefundAmountNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                   RESTART-STREAM
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenPaused() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    WITHDRAW-AT
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenCallerRecipient() {
        _;
    }

    modifier whenLastTimeNotLessThanWithdrawalTime() {
        _;
    }

    modifier whenToNonZeroAddress() {
        _;
    }

    modifier whenWithdrawalAddressIsRecipient() {
        _;
    }

    modifier whenWithdrawalAddressNotRecipient() {
        _;
    }

    modifier whenWithdrawalTimeNotInTheFuture() {
        _;
    }
}
