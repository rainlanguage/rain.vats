// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {console2} from "forge-std/Test.sol";
import {
    OwnerFreezableOwnerFreezeUntilTest,
    IOwnerFreezableV1
} from "test/abstract/OwnerFreezableOwnerFreezeUntilTest.sol";
import {OffchainAssetReceiptVault} from "src/concrete/vault/OffchainAssetReceiptVault.sol";
import {IReceiptV3} from "src/concrete/receipt/Receipt.sol";
import {
    CERTIFY,
    DEPOSIT,
    WITHDRAW,
    CONFISCATE_SHARES,
    CONFISCATE_RECEIPT
} from "src/concrete/authorize/OffchainAssetReceiptVaultAuthorizerV1.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";

contract OffchainAssetReceiptVaultOwnerFreezeUntilTest is OwnerFreezableOwnerFreezeUntilTest {
    constructor() {
        sAlice = address(123456);
        sBob = address(949330);

        sOwnerFreezable = IOwnerFreezableV1(createVault(sAlice, "vault", "VLT"));
    }

    function setupTokenTransferTest() internal returns (OffchainAssetReceiptVault) {
        vm.startPrank(sAlice);
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(payable(address(sOwnerFreezable)));
        IAccessControl(address(vault.authorizer())).grantRole(CERTIFY, sAlice);
        vault.certify(block.timestamp + 1, false, "");

        IAccessControl(address(vault.authorizer())).grantRole(DEPOSIT, sAlice);
        vault.deposit(1e18, sBob, 0, "");
        vm.stopPrank();
        return vault;
    }

    function giveReasonToTransfer(uint256 seed, address from, address to) internal {
        OffchainAssetReceiptVault vault = OffchainAssetReceiptVault(payable(address(sOwnerFreezable)));
        seed = bound(seed, 0, 2);
        if (seed == 0) {
            console2.log("Giving reason to transfer from:", from);
            vm.prank(sAlice);
            vault.ownerFreezeAlwaysAllowFrom(from, block.timestamp + 1);
            assertEq(vault.ownerFreezeAlwaysAllowedFrom(from), block.timestamp + 1);
        } else if (seed == 1) {
            console2.log("Giving reason to transfer to:", to);
            vm.prank(sAlice);
            vault.ownerFreezeAlwaysAllowTo(to, block.timestamp + 1);
            assertEq(vault.ownerFreezeAlwaysAllowedTo(to), block.timestamp + 1);
        } else {
            console2.log("Giving reason to transfer from:", from, "to:", to);
            uint256 frozenUntil = vault.ownerFrozenUntil();
            vm.warp(frozenUntil);
        }
    }

    function testTokenTransferNotFroze() external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();

        vm.prank(sBob);
        assertTrue(vault.transfer(sAlice, 1e18));
    }

    function testTokenTransferFroze(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();

        uint256 freezeUntil = block.timestamp + 1;
        vm.prank(sAlice);
        vault.ownerFreezeUntil(freezeUntil);

        // Cannot transfer while frozen.
        vm.prank(sBob);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, sAlice));
        assertFalse(vault.transfer(sAlice, 1e18));

        // Can transfer again if there's a reason to allow it.
        giveReasonToTransfer(seed, sBob, sAlice);
        vm.prank(sBob);
        assertTrue(vault.transfer(sAlice, 1e18));

        // Alice can't transfer while everything is frozen.
        vm.warp(freezeUntil - 1);
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sAlice, sBob));
        assertFalse(vault.transfer(sBob, 1e18));
    }

    function testReceiptTransferFroze(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();

        IReceiptV3 receipt = vault.receipt();

        uint256 freezeUntil = block.timestamp + 1;
        vm.prank(sAlice);
        vault.ownerFreezeUntil(freezeUntil);

        // Cannot transfer while frozen.
        vm.startPrank(sBob);

        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, sAlice));
        receipt.safeTransferFrom(sBob, sAlice, 1, 1e18, "");
        vm.stopPrank();

        // Can transfer again if there's a reason to allow it.
        giveReasonToTransfer(seed, sBob, sAlice);
        vm.startPrank(sBob);
        receipt.safeTransferFrom(sBob, sAlice, 1, 1e18, "");
        vm.stopPrank();

        // Alice can't transfer while everything is frozen.
        vm.warp(freezeUntil - 1);
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sAlice, sBob));
        receipt.safeTransferFrom(sAlice, sBob, 1, 1e18, "");
        vm.stopPrank();
    }

    function testTokenDepositFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        uint256 freezeUntil = block.timestamp + 1;
        vm.prank(sAlice);
        vault.ownerFreezeUntil(freezeUntil);

        // Alice cannot deposit while frozen.
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, address(0), sBob));
        vault.deposit(1e18, sBob, 0, "");

        // But if there's a reason to allow it, she can.
        giveReasonToTransfer(seed, address(0), sBob);
        vm.prank(sAlice);
        vault.deposit(1e18, sBob, 0, "");
    }

    function testTokenMintFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        uint256 freezeUntil = block.timestamp + 1;
        vm.prank(sAlice);
        vault.ownerFreezeUntil(freezeUntil);

        // Alice cannot mint while frozen.
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, address(0), sBob));
        vault.mint(1e18, sBob, 0, "");

        // But if there's a reason to allow it, she can.
        giveReasonToTransfer(seed, address(0), sBob);
        vm.prank(sAlice);
        vault.mint(1e18, sBob, 0, "");
    }

    function testTokenRedepositFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();

        // Alice deposits some token.
        vm.prank(sAlice);
        vault.deposit(1e18, sAlice, 0, "");

        // Vault gets frozen.
        vm.prank(sAlice);
        uint256 freezeUntil = block.timestamp + 1;
        vault.ownerFreezeUntil(freezeUntil);

        // Alice cannot redeposit.
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, address(0), sAlice));
        vault.redeposit(1e18, sAlice, 1, "");

        // Unless there's a reason for redepositing.
        giveReasonToTransfer(seed, address(0), sAlice);
        vm.prank(sAlice);
        vault.redeposit(1e18, sAlice, 1, "");
    }

    function testTokenWithdrawFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        vm.startPrank(sAlice);
        IAccessControl(address(vault.authorizer())).grantRole(WITHDRAW, sBob);

        uint256 freezeUntil = block.timestamp + 1;
        vault.ownerFreezeUntil(freezeUntil);
        vm.stopPrank();

        // Bob can't withdraw to himself while frozen.
        vm.prank(sBob);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, address(0)));
        vault.withdraw(1e18, sBob, sBob, 1, "");
        // But if there's a reason to allow it, he can.
        giveReasonToTransfer(seed, sBob, address(0));
        vm.prank(sBob);
        vault.withdraw(1e18, sBob, sBob, 1, "");
    }

    function testTokenRedeemFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        vm.startPrank(sAlice);
        IAccessControl(address(vault.authorizer())).grantRole(WITHDRAW, sBob);

        uint256 freezeUntil = block.timestamp + 1;
        vault.ownerFreezeUntil(freezeUntil);
        vm.stopPrank();

        // Bob can't withdraw to himself while frozen.
        vm.prank(sBob);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, address(0)));
        vault.redeem(1e18, sBob, sBob, 1, "");
        // But if there's a reason to allow it, he can.
        giveReasonToTransfer(seed, sBob, address(0));
        vm.prank(sBob);
        vault.redeem(1e18, sBob, sBob, 1, "");
    }

    function testTokenConfiscateFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        vm.startPrank(sAlice);
        IAccessControl(address(vault.authorizer())).grantRole(CONFISCATE_SHARES, sAlice);

        uint256 freezeUntil = block.timestamp + 1;
        vault.ownerFreezeUntil(freezeUntil);
        vm.stopPrank();

        // Alice can't confiscate from Bob while frozen.
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, sAlice));
        vault.confiscateShares(sBob, 1e18, "");

        giveReasonToTransfer(seed, sBob, sAlice);
        vm.prank(sAlice);
        vault.confiscateShares(sBob, 1e18, "");
    }

    function testReceiptConfiscateFrozen(uint256 seed) external {
        OffchainAssetReceiptVault vault = setupTokenTransferTest();
        vm.startPrank(sAlice);
        IAccessControl(address(vault.authorizer())).grantRole(CONFISCATE_RECEIPT, sAlice);

        uint256 freezeUntil = block.timestamp + 1;
        vault.ownerFreezeUntil(freezeUntil);
        vm.stopPrank();

        // Alice can't confiscate from Bob while frozen.
        vm.prank(sAlice);
        vm.expectRevert(abi.encodeWithSelector(IOwnerFreezableV1.OwnerFrozen.selector, freezeUntil, sBob, sAlice));
        vault.confiscateReceipt(sBob, 1, 1e18, "");

        giveReasonToTransfer(seed, sBob, sAlice);
        vm.prank(sAlice);
        vault.confiscateReceipt(sBob, 1, 1e18, "");
    }
}
