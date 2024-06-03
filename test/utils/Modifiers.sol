// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity >=0.8.22;

abstract contract Modifiers {
    /*//////////////////////////////////////////////////////////////////////////
                                       COMMON
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenBalanceIsNotZero() virtual {
        _;
    }

    modifier givenNotNull() {
        _;
    }

    modifier givenNotPaused() {
        _;
    }

    modifier whenAssetDoesNotMissERC20Return() {
        _;
    }

    modifier whenCallerNotSender() {
        _;
    }

    modifier whenCallerSender() {
        _;
    }

    modifier whenNoDelegateCall() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                              ADJUST-AMOUNT-PER-SECOND
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenNewRatePerSecondIsNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       CREATE
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenAssetDecimalsDoesNotExceed18() {
        _;
    }

    modifier whenAssetImplementsDecimals() {
        _;
    }

    modifier whenRatePerSecondIsNotZero() {
        _;
    }

    modifier whenSenderIsNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      DEPOSIT
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenBrokerAddressIsNotZero() {
        _;
    }

    modifier whenBrokerFeeNotGreaterThanMaxFee() {
        _;
    }

    modifier whenDepositAmountIsNotZero() {
        _;
    }

    modifier whenTotalAmountIsNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                       REFUND
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenNoOverRefund() {
        _;
    }

    modifier whenRefundAmountIsNotZero() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                      RESTART
    //////////////////////////////////////////////////////////////////////////*/

    modifier givenPaused() {
        _;
    }

    /*//////////////////////////////////////////////////////////////////////////
                                    WITHDRAW-AT
    //////////////////////////////////////////////////////////////////////////*/

    modifier whenWithdrawalAddressIsNotOwner() {
        _;
    }

    modifier whenWithdrawalAddressIsNotZero() {
        _;
    }

    modifier whenWithdrawalAddressIsOwner() {
        _;
    }
}
