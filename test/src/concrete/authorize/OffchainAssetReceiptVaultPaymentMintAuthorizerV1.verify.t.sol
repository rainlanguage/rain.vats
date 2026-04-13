// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {OffchainAssetReceiptVaultAuthorizerV1Test} from "test/abstract/OffchainAssetReceiptVaultAuthorizerV1Test.sol";
import {CloneFactory} from "rain.factory/concrete/CloneFactory.sol";
import {
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1,
    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config,
    Unauthorized
} from "src/concrete/authorize/OffchainAssetReceiptVaultPaymentMintAuthorizerV1.sol";
import {DepositStateChange, DEPOSIT, CERTIFY} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {
    IVerifyV1,
    VerifyStatus,
    VERIFY_STATUS_NIL,
    VERIFY_STATUS_ADDED,
    VERIFY_STATUS_APPROVED,
    VERIFY_STATUS_BANNED
} from "rain.verify.interface/interface/IVerifyV1.sol";
import {VerifyAlwaysApproved} from "rain.verify.interface/concrete/VerifyAlwaysApproved.sol";
import {TestErc20} from "test/concrete/TestErc20.sol";

contract OffchainAssetReceiptVaultPaymentMintAuthorizerV1VerifyTest is OffchainAssetReceiptVaultAuthorizerV1Test {
    address constant VERIFY_CONTRACT = address(uint160(uint256(keccak256("VERIFY_CONTRACT"))));
    address constant ALICE = address(uint160(uint256(keccak256("ALICE.VERIFY"))));
    address constant BOB = address(uint160(uint256(keccak256("BOB.VERIFY"))));

    function newAuthorizerWithVerify(address receiptVault, address owner, address paymentToken, address verify)
        internal
        returns (OffchainAssetReceiptVaultPaymentMintAuthorizerV1)
    {
        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 implementation =
            new OffchainAssetReceiptVaultPaymentMintAuthorizerV1();
        CloneFactory factory = new CloneFactory();
        return OffchainAssetReceiptVaultPaymentMintAuthorizerV1(
            factory.clone(
                address(implementation),
                abi.encode(
                    OffchainAssetReceiptVaultPaymentMintAuthorizerV1Config({
                        receiptVault: receiptVault,
                        verify: verify,
                        owner: owner,
                        paymentToken: paymentToken,
                        maxSharesSupply: 1e27
                    })
                )
            )
        );
    }

    function mockVerifyStatus(address verify, address account, VerifyStatus status) internal {
        vm.mockCall(
            verify,
            abi.encodeWithSelector(IVerifyV1.accountStatusAtTime.selector, account, block.timestamp),
            abi.encode(status)
        );
    }

    function depositData(address owner, uint256 shares) internal pure returns (bytes memory) {
        return abi.encode(
            DepositStateChange({
                owner: owner, receiver: owner, id: 1, assetsDeposited: shares, sharesMinted: shares, data: ""
            })
        );
    }

    /// Approved user can deposit.
    function testVerifyApprovedCanDeposit() external {
        vm.prank(ALICE);
        TestErc20 paymentToken = new TestErc20();

        address receiptVault = address(uint160(uint256(keccak256("RECEIPT_VAULT.VERIFY"))));
        vm.etch(VERIFY_CONTRACT, hex"00");

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizerWithVerify(receiptVault, BOB, address(paymentToken), VERIFY_CONTRACT);

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));
        mockVerifyStatus(VERIFY_CONTRACT, ALICE, VERIFY_STATUS_APPROVED);

        vm.prank(ALICE);
        paymentToken.approve(address(authorizer), 1e18);

        vm.prank(receiptVault);
        authorizer.authorize(ALICE, DEPOSIT, depositData(ALICE, 1e18));
    }

    /// NIL status user cannot deposit.
    function testVerifyNilReverts() external {
        vm.prank(ALICE);
        TestErc20 paymentToken = new TestErc20();

        address receiptVault = address(uint160(uint256(keccak256("RECEIPT_VAULT.VERIFY"))));
        vm.etch(VERIFY_CONTRACT, hex"00");

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizerWithVerify(receiptVault, BOB, address(paymentToken), VERIFY_CONTRACT);

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));
        mockVerifyStatus(VERIFY_CONTRACT, ALICE, VERIFY_STATUS_NIL);

        vm.prank(ALICE);
        paymentToken.approve(address(authorizer), 1e18);

        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, ALICE, DEPOSIT, depositData(ALICE, 1e18)));
        authorizer.authorize(ALICE, DEPOSIT, depositData(ALICE, 1e18));
    }

    /// ADDED (but not approved) user cannot deposit.
    function testVerifyAddedReverts() external {
        vm.prank(ALICE);
        TestErc20 paymentToken = new TestErc20();

        address receiptVault = address(uint160(uint256(keccak256("RECEIPT_VAULT.VERIFY"))));
        vm.etch(VERIFY_CONTRACT, hex"00");

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizerWithVerify(receiptVault, BOB, address(paymentToken), VERIFY_CONTRACT);

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));
        mockVerifyStatus(VERIFY_CONTRACT, ALICE, VERIFY_STATUS_ADDED);

        vm.prank(ALICE);
        paymentToken.approve(address(authorizer), 1e18);

        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, ALICE, DEPOSIT, depositData(ALICE, 1e18)));
        authorizer.authorize(ALICE, DEPOSIT, depositData(ALICE, 1e18));
    }

    /// BANNED user cannot deposit.
    function testVerifyBannedReverts() external {
        vm.prank(ALICE);
        TestErc20 paymentToken = new TestErc20();

        address receiptVault = address(uint160(uint256(keccak256("RECEIPT_VAULT.VERIFY"))));
        vm.etch(VERIFY_CONTRACT, hex"00");

        OffchainAssetReceiptVaultPaymentMintAuthorizerV1 authorizer =
            newAuthorizerWithVerify(receiptVault, BOB, address(paymentToken), VERIFY_CONTRACT);

        vm.mockCall(receiptVault, abi.encodeWithSelector(IERC20.totalSupply.selector), abi.encode(0));
        mockVerifyStatus(VERIFY_CONTRACT, ALICE, VERIFY_STATUS_BANNED);

        vm.prank(ALICE);
        paymentToken.approve(address(authorizer), 1e18);

        vm.prank(receiptVault);
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, ALICE, DEPOSIT, depositData(ALICE, 1e18)));
        authorizer.authorize(ALICE, DEPOSIT, depositData(ALICE, 1e18));
    }
}
