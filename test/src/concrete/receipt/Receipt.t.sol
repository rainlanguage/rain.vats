// SPDX-License-Identifier: LicenseRef-DCL-1.0
// SPDX-FileCopyrightText: Copyright (c) 2020 Rain Open Source Software Ltd
pragma solidity =0.8.25;

import {Receipt as ReceiptContract, IReceiptV3} from "src/concrete/receipt/Receipt.sol";
import {TestReceiptManager, UnauthorizedTransfer} from "test/concrete/TestReceiptManager.sol";
import {LibUniqueAddressesGenerator} from "../../../lib/LibUniqueAddressesGenerator.sol";
import {ReceiptFactoryTest} from "test/abstract/ReceiptFactoryTest.sol";
import {OnlyManager} from "src/error/ErrReceipt.sol";
import {IERC1155Errors} from "openzeppelin-contracts-upgradeable/contracts/token/ERC1155/ERC1155Upgradeable.sol";

contract ReceiptTest is ReceiptFactoryTest {
    function testInitialize() public {
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));
        assertEq(receipt.manager(), address(testManager));
    }

    /// Check that alice can't mint herself directly on the receipt.
    function testManagerMintRevertAlice(uint256 aliceSeed, uint256 id, uint256 amount, bytes memory data) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        amount = bound(amount, 1, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(OnlyManager.selector));
        receipt.managerMint(alice, alice, id, amount, data);
    }

    /// Test receipt ManagerMint function
    function testManagerMint(uint256 aliceSeed, uint256 id, uint256 amount, bytes memory data) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        amount = bound(amount, 1, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, data);

        // Check the receipt balance of alice
        assertEq(receipt.balanceOf(alice, id), amount);
    }

    /// Check that alice can't burn herself directly on the receipt.
    function testManagerBurnRevertAlice(uint256 aliceSeed, uint256 id, uint256 amount, bytes memory data) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        amount = bound(amount, 1, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        vm.expectRevert(abi.encodeWithSelector(OnlyManager.selector));
        receipt.managerBurn(alice, alice, id, amount, data);
    }

    /// Test receipt ManagerBurn function
    function testManagerBurn(uint256 aliceSeed, uint256 id, uint256 amount, bytes memory receiptInformation) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        vm.assume(receiptInformation.length > 0);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, receiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        testManager.setFrom(alice);
        testManager.setTo(address(0));

        // Set up the event expectation for ReceiptInformation
        vm.expectEmit(false, false, false, true);
        emit IReceiptV3.ReceiptInformation(alice, id, receiptInformation);

        testManager.managerBurn(receipt, alice, id, receiptBalance, receiptInformation);

        // Check the balance of alice
        assertEq(receipt.balanceOf(alice, id), 0);
    }

    /// Test ManagerBurn fails while not enough balance to burn
    function testManagerBurnNotEnoughBalance(
        uint256 aliceSeed,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation,
        uint256 burnAmount
    ) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        // Bound with uint256 max - 1 so dowsnot get overflow while bounding burnAmount
        amount = bound(amount, 1, type(uint256).max - 1);
        id = bound(id, 0, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, receiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);
        burnAmount = bound(burnAmount, receiptBalance + 1, type(uint256).max);

        testManager.setFrom(alice);
        testManager.setTo(address(0));

        vm.expectRevert();
        testManager.managerBurn(receipt, alice, id, burnAmount, receiptInformation);
    }

    /// Test managerTransferFrom more than balance
    function testManagerTransferFromMoreThanBalance(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation,
        uint256 transferAmount
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        // Bound with uint256 max - 1 so dowsnot get overflow while bounding transferAmount
        amount = bound(amount, 1, type(uint256).max - 1);
        id = bound(id, 0, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, receiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);
        transferAmount = bound(transferAmount, receiptBalance + 1, type(uint256).max);

        testManager.setFrom(alice);
        testManager.setTo(bob);

        vm.expectRevert();
        testManager.managerTransferFrom(receipt, alice, bob, id, transferAmount, receiptInformation);
    }

    /// Test receipt ManagerTransferFrom function reverts while UnauthorizedTransfer
    function testUnauthorizedTransferManagerTransferFrom(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, receiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        testManager.setFrom(alice);
        testManager.setTo(address(0));

        vm.expectRevert(abi.encodeWithSelector(UnauthorizedTransfer.selector, alice, bob));
        testManager.managerTransferFrom(receipt, alice, bob, id, receiptBalance, receiptInformation);
    }

    /// Alice can't transfer to herself using managerTransferFrom.
    function testManagerTransferFromSelf(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Alice can't transfer to herself.
        vm.expectRevert(abi.encodeWithSelector(OnlyManager.selector));
        receipt.managerTransferFrom(alice, bob, alice, id, amount, receiptInformation);
    }

    /// Test receipt managerTransferFrom function
    function testTransferManagerTransferFrom(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 id,
        uint256 amount,
        bytes memory receiptInformation
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        amount = bound(amount, 1, type(uint256).max);
        id = bound(id, 0, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        vm.startPrank(alice);
        testManager.managerMint(receipt, alice, id, amount, receiptInformation);
        uint256 receiptBalance = receipt.balanceOf(alice, id);

        testManager.setFrom(alice);
        testManager.setTo(bob);

        testManager.managerTransferFrom(receipt, alice, bob, id, receiptBalance, receiptInformation);

        assertEq(receipt.balanceOf(bob, id), receiptBalance);
        assertEq(receipt.balanceOf(alice, id), 0);
    }

    /// Test ERC1155 balanceOf function
    function testBalanceOf(uint256 aliceSeed, uint256 id, uint256 amount, bytes memory data) external {
        address alice = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed);

        amount = bound(amount, 1, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, id, amount, data);

        uint256 balance = receipt.balanceOf(alice, id);

        // Check the receipt balance of alice
        assertEq(balance, amount);
    }

    /// Test ERC1155 balanceOfBatch function
    function testBalanceOfBatch(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 idOne,
        uint256 idTwo,
        uint256 amountOne,
        uint256 amountTwo,
        bytes memory data
    ) external {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);
        vm.assume(alice != bob);

        amountOne = bound(amountOne, 1, type(uint256).max);
        amountTwo = bound(amountTwo, 1, type(uint256).max);
        vm.assume(amountOne != amountTwo);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, idOne, amountOne, data);

        testManager.setTo(bob);
        testManager.managerMint(receipt, bob, idTwo, amountTwo, data);

        address[] memory addresses = new address[](2);
        addresses[0] = alice;
        addresses[1] = bob;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = idOne;
        tokenIds[1] = idTwo;

        uint256[] memory balances = receipt.balanceOfBatch(addresses, tokenIds);

        // Check the receipt balance of alice
        assertEq(balances[0], amountOne);
        assertEq(balances[1], amountTwo);
    }

    /// Test ERC1155 setApprovalForAll And IsApprovedForAll function
    function testSetApprovalForAllAndIsApprovedForAll(uint256 aliceSeed, uint256 bobSeed) public {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);

        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(alice))));

        vm.startPrank(alice);
        // Alice approves operator
        receipt.setApprovalForAll(bob, true);
        assertTrue(receipt.isApprovedForAll(alice, bob));

        // Alice revokes approval
        receipt.setApprovalForAll(bob, false);
        assertFalse(receipt.isApprovedForAll(alice, bob));
    }

    /// Test ERC1155 safeTransferFrom function
    function testSafeTransferFrom(uint256 aliceSeed, uint256 bobSeed, uint256 tokenId, uint256 amount) public {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);

        amount = bound(amount, 1, type(uint256).max);

        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Set the authorized 'from' and 'to' addresses in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        testManager.managerMint(receipt, alice, tokenId, amount, "");

        // Check UnauthorizedTransfer reverts
        vm.expectRevert(abi.encodeWithSelector(UnauthorizedTransfer.selector, alice, bob));
        receipt.safeTransferFrom(alice, bob, tokenId, amount, "");

        // Expect revert on transfer to zero address
        testManager.setTo(address(0));
        vm.expectRevert(abi.encodeWithSelector(IERC1155Errors.ERC1155InvalidReceiver.selector, address(0)));
        receipt.safeTransferFrom(alice, address(0), tokenId, amount, "");

        testManager.setFrom(alice);
        testManager.setTo(bob);

        // Perform transfer
        receipt.safeTransferFrom(alice, bob, tokenId, amount, "");
        assertEq(receipt.balanceOf(alice, tokenId), 0);
        assertEq(receipt.balanceOf(bob, tokenId), amount);
    }

    /// Test ERC1155 safeBatchTransferFrom function
    function testSafeBatchTransferFrom(
        uint256 aliceSeed,
        uint256 bobSeed,
        uint256 tokenId1,
        uint256 tokenId2,
        uint256 amount1,
        uint256 amount2
    ) public {
        (address alice, address bob) = LibUniqueAddressesGenerator.generateUniqueAddresses(vm, aliceSeed, bobSeed);

        vm.assume(alice != bob);

        vm.assume(tokenId1 != tokenId2);

        // Ensure amounts are bounded to avoid zero transfers
        amount1 = bound(amount1, 1, type(uint256).max);
        amount2 = bound(amount2, 1, type(uint256).max);
        vm.assume(amount1 != amount2);

        // Define arrays with token IDs and amounts
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = amount1;
        amounts[1] = amount2;

        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = tokenId1;
        tokenIds[1] = tokenId2;
        // Create a new receipt
        TestReceiptManager testManager = new TestReceiptManager();
        ReceiptContract receipt =
            ReceiptContract(iFactory.clone(address(iReceiptImplementation), abi.encode(address(testManager))));

        vm.startPrank(alice);

        // Authorize alice as the sender and receiver in testManager
        testManager.setFrom(address(0));
        testManager.setTo(alice);

        // Mint the specified token IDs and amounts to alice
        testManager.managerMint(receipt, alice, tokenId1, amount1, "");
        testManager.managerMint(receipt, alice, tokenId2, amount2, "");

        // Set the valid from/to addresses for the transfer
        testManager.setFrom(alice);
        testManager.setTo(bob);

        // Perform batch transfer
        receipt.safeBatchTransferFrom(alice, bob, tokenIds, amounts, "");

        // Verify balances are updated correctly
        assertEq(receipt.balanceOf(alice, tokenId1), 0);
        assertEq(receipt.balanceOf(bob, tokenId1), amount1);
        assertEq(receipt.balanceOf(alice, tokenId2), 0);
        assertEq(receipt.balanceOf(bob, tokenId2), amount2);
    }
}
