/// Tests for PrivacyPool contract
use starknet::ContractAddress;
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use veil::IPrivacyPoolDispatcher;
use veil::IPrivacyPoolDispatcherTrait;
use veil::IPrivacyPoolSafeDispatcher;
use veil::IPrivacyPoolSafeDispatcherTrait;
use veil::constants::{TREE_DEPTH, get_zero_hash};
use veil::commitment::create_commitment;
use veil::note::create_note;

fn deploy_privacy_pool() -> ContractAddress {
    let contract = declare("PrivacyPool").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
    contract_address
}

#[test]
fn test_constructor_initializes_correctly() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Initial commitment count should be zero
    let count = dispatcher.get_commitment_count();
    assert(count == 0, 'Initial count should be 0');

    // Initial root should be the zero tree root
    let root = dispatcher.get_merkle_root();
    let expected_root = get_zero_hash(TREE_DEPTH);
    assert(root == expected_root, 'Wrong initial root');
}

#[test]
fn test_single_deposit_updates_root() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    let initial_root = dispatcher.get_merkle_root();

    // Deposit a commitment
    let commitment: felt252 = 0x123456789abcdef;
    dispatcher.deposit(commitment);

    // Root should have changed
    let new_root = dispatcher.get_merkle_root();
    assert(new_root != initial_root, 'Root should change');

    // Count should be 1
    let count = dispatcher.get_commitment_count();
    assert(count == 1, 'Count should be 1');

    // Commitment should be stored at index 0
    let stored_commitment = dispatcher.get_commitment(0);
    assert(stored_commitment == commitment, 'Commitment not stored');
}

#[test]
fn test_multiple_sequential_deposits() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    let commitment1: felt252 = 0x111;
    let commitment2: felt252 = 0x222;
    let commitment3: felt252 = 0x333;

    // First deposit
    dispatcher.deposit(commitment1);
    let root_after_1 = dispatcher.get_merkle_root();

    // Second deposit
    dispatcher.deposit(commitment2);
    let root_after_2 = dispatcher.get_merkle_root();
    assert(root_after_2 != root_after_1, 'Root should change');

    // Third deposit
    dispatcher.deposit(commitment3);
    let root_after_3 = dispatcher.get_merkle_root();
    assert(root_after_3 != root_after_2, 'Root unchanged');

    // Count should be 3
    let count = dispatcher.get_commitment_count();
    assert(count == 3, 'Count should be 3');

    // All commitments should be retrievable
    assert(dispatcher.get_commitment(0) == commitment1, 'Commit 1 mismatch');
    assert(dispatcher.get_commitment(1) == commitment2, 'Commit 2 mismatch');
    assert(dispatcher.get_commitment(2) == commitment3, 'Commit 3 mismatch');
}

#[test]
fn test_commitment_retrieval_by_index() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Deposit multiple commitments
    let mut i: u256 = 0;
    loop {
        if i >= 5 {
            break;
        }
        let commitment: felt252 = (i + 1).try_into().unwrap();
        dispatcher.deposit(commitment);
        i += 1;
    };

    // Retrieve each by index
    assert(dispatcher.get_commitment(0) == 1, 'Index 0 should be 1');
    assert(dispatcher.get_commitment(1) == 2, 'Index 1 should be 2');
    assert(dispatcher.get_commitment(2) == 3, 'Index 2 should be 3');
    assert(dispatcher.get_commitment(3) == 4, 'Index 3 should be 4');
    assert(dispatcher.get_commitment(4) == 5, 'Index 4 should be 5');
}

#[test]
fn test_nullifier_checks_return_false_initially() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // No nullifiers should be used initially
    let nullifier1: felt252 = 0xdeadbeef;
    let nullifier2: felt252 = 0xcafebabe;

    assert(!dispatcher.is_nullifier_used(nullifier1), 'Nullifier1 used');
    assert(!dispatcher.is_nullifier_used(nullifier2), 'Nullifier2 used');
}

#[test]
fn test_get_nonexistent_commitment() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Reading a commitment at an unused index should return 0
    let commitment = dispatcher.get_commitment(999);
    assert(commitment == 0, 'Unused index != 0');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_deposit_zero_commitment() {
    let contract_address = deploy_privacy_pool();
    let safe_dispatcher = IPrivacyPoolSafeDispatcher { contract_address };

    match safe_dispatcher.deposit(0) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Commitment cannot be zero', *panic_data.at(0));
        }
    };
}

#[test]
fn test_root_changes_predictably() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Deposit same commitment twice in fresh contracts should give same root
    let commitment: felt252 = 0xabcdef123456;
    dispatcher.deposit(commitment);
    let root1 = dispatcher.get_merkle_root();

    // Deploy fresh contract
    let contract_address2 = deploy_privacy_pool();
    let dispatcher2 = IPrivacyPoolDispatcher { contract_address: contract_address2 };
    dispatcher2.deposit(commitment);
    let root2 = dispatcher2.get_merkle_root();

    assert(root1 == root2, 'Roots differ unexpectedly');
}

// ============ Phase 2 Tests: Withdraw and Transfer ============

/// Helper to build a Merkle proof for a single leaf at index 0
/// Uses zero hashes for all siblings
fn build_merkle_proof_for_index_0() -> Array<felt252> {
    let mut proof = ArrayTrait::new();
    let mut level: u8 = 0;
    loop {
        if level >= TREE_DEPTH {
            break;
        }
        proof.append(get_zero_hash(level));
        level += 1;
    };
    proof
}

#[test]
fn test_withdraw_marks_nullifier_spent() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Create a note
    let amount: u64 = 10_000_000; // 0.1 BTC
    let secret: felt252 = 0xabcdef123;
    let index: u256 = 0;
    let note = create_note(amount, secret, index);

    // Deposit the commitment
    dispatcher.deposit(note.commitment);
    let _merkle_root = dispatcher.get_merkle_root();

    // Build merkle proof
    let proof = build_merkle_proof_for_index_0();
    let recipient: felt252 = 0xb1c0123456;

    // Withdraw
    dispatcher.withdraw(
        note.nullifier,
        amount,
        recipient,
        proof.span(),
        amount,
        secret,
        note.nullifier,
        index,
    );

    // Verify nullifier is now spent
    assert(dispatcher.is_nullifier_used(note.nullifier), 'Nullifier should be spent');
}

#[test]
fn test_withdraw_updates_total() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    let amount: u64 = 10_000_000;
    let secret: felt252 = 0xabcdef123;
    let index: u256 = 0;
    let note = create_note(amount, secret, index);

    dispatcher.deposit(note.commitment);

    let proof = build_merkle_proof_for_index_0();
    let recipient: felt252 = 0xb1c0123456;

    // Check initial total withdrawn
    let initial_withdrawn = dispatcher.get_total_withdrawn();
    assert(initial_withdrawn == 0, 'Initial withdrawn 0');

    dispatcher.withdraw(
        note.nullifier,
        amount,
        recipient,
        proof.span(),
        amount,
        secret,
        note.nullifier,
        index,
    );

    // Verify total withdrawn updated
    let final_withdrawn = dispatcher.get_total_withdrawn();
    let expected: u256 = amount.into();
    assert(final_withdrawn == expected, 'Withdrawn should update');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_double_spend_withdrawal() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };
    let safe_dispatcher = IPrivacyPoolSafeDispatcher { contract_address };

    let amount: u64 = 10_000_000;
    let secret: felt252 = 0xabcdef123;
    let index: u256 = 0;
    let note = create_note(amount, secret, index);

    dispatcher.deposit(note.commitment);

    let proof = build_merkle_proof_for_index_0();
    let recipient: felt252 = 0xb1c0123456;

    // First withdrawal succeeds
    dispatcher.withdraw(
        note.nullifier,
        amount,
        recipient,
        proof.span(),
        amount,
        secret,
        note.nullifier,
        index,
    );

    // Second withdrawal should fail
    match safe_dispatcher.withdraw(
        note.nullifier,
        amount,
        recipient,
        proof.span(),
        amount,
        secret,
        note.nullifier,
        index,
    ) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Nullifier already spent', *panic_data.at(0));
        }
    };
}

#[test]
fn test_transfer_single_input_two_outputs() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };

    // Create input note (1.0 BTC)
    let input_amount: u64 = 100_000_000;
    let input_secret: felt252 = 0x111111;
    let input_index: u256 = 0;
    let input_note = create_note(input_amount, input_secret, input_index);

    // Deposit input
    dispatcher.deposit(input_note.commitment);
    let initial_count = dispatcher.get_commitment_count();
    assert(initial_count == 1, 'Should have 1 commitment');

    // Create outputs (0.6 + 0.4 BTC)
    let output1_amount: u64 = 60_000_000;
    let output1_secret: felt252 = 0x222222;
    let output1_nullifier: felt252 = 0xaaa;
    let output1_commitment = create_commitment(output1_amount, output1_secret, output1_nullifier);

    let output2_amount: u64 = 40_000_000;
    let output2_secret: felt252 = 0x333333;
    let output2_nullifier: felt252 = 0xbbb;
    let output2_commitment = create_commitment(output2_amount, output2_secret, output2_nullifier);

    // Build arrays
    let mut nullifiers = ArrayTrait::new();
    nullifiers.append(input_note.nullifier);

    let mut output_commitments = ArrayTrait::new();
    output_commitments.append(output1_commitment);
    output_commitments.append(output2_commitment);

    let proof = build_merkle_proof_for_index_0();
    let mut merkle_proofs = ArrayTrait::new();
    merkle_proofs.append(proof.span());

    let mut input_amounts = ArrayTrait::new();
    input_amounts.append(input_amount);

    let mut input_secrets = ArrayTrait::new();
    input_secrets.append(input_secret);

    let mut input_nullifiers = ArrayTrait::new();
    input_nullifiers.append(input_note.nullifier);

    let mut input_indices = ArrayTrait::new();
    input_indices.append(input_index);

    let mut output_amounts = ArrayTrait::new();
    output_amounts.append(output1_amount);
    output_amounts.append(output2_amount);

    let mut output_secrets = ArrayTrait::new();
    output_secrets.append(output1_secret);
    output_secrets.append(output2_secret);

    let mut output_nullifiers_arr = ArrayTrait::new();
    output_nullifiers_arr.append(output1_nullifier);
    output_nullifiers_arr.append(output2_nullifier);

    // Execute transfer
    dispatcher.transfer(
        nullifiers.span(),
        output_commitments.span(),
        merkle_proofs.span(),
        input_amounts.span(),
        input_secrets.span(),
        input_nullifiers.span(),
        input_indices.span(),
        output_amounts.span(),
        output_secrets.span(),
        output_nullifiers_arr.span(),
    );

    // Verify input nullifier is spent
    assert(dispatcher.is_nullifier_used(input_note.nullifier), 'Input should be spent');

    // Verify commitment count increased by 2
    let final_count = dispatcher.get_commitment_count();
    assert(final_count == 3, 'Should have 3 commits');

    // Verify output commitments are stored
    assert(dispatcher.get_commitment(1) == output1_commitment, 'Output 1 mismatch');
    assert(dispatcher.get_commitment(2) == output2_commitment, 'Output 2 mismatch');
}

#[test]
#[feature("safe_dispatcher")]
fn test_transfer_balance_mismatch_fails() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };
    let safe_dispatcher = IPrivacyPoolSafeDispatcher { contract_address };

    // Create input note (1.0 BTC)
    let input_amount: u64 = 100_000_000;
    let input_secret: felt252 = 0x111111;
    let input_index: u256 = 0;
    let input_note = create_note(input_amount, input_secret, input_index);

    dispatcher.deposit(input_note.commitment);

    // Create outputs that don't sum to input (0.6 + 0.5 = 1.1 BTC != 1.0 BTC)
    let output1_amount: u64 = 60_000_000;
    let output1_secret: felt252 = 0x222222;
    let output1_nullifier: felt252 = 0xaaa;
    let output1_commitment = create_commitment(output1_amount, output1_secret, output1_nullifier);

    let output2_amount: u64 = 50_000_000; // Wrong! Should be 40_000_000
    let output2_secret: felt252 = 0x333333;
    let output2_nullifier: felt252 = 0xbbb;
    let output2_commitment = create_commitment(output2_amount, output2_secret, output2_nullifier);

    let mut nullifiers = ArrayTrait::new();
    nullifiers.append(input_note.nullifier);

    let mut output_commitments = ArrayTrait::new();
    output_commitments.append(output1_commitment);
    output_commitments.append(output2_commitment);

    let proof = build_merkle_proof_for_index_0();
    let mut merkle_proofs = ArrayTrait::new();
    merkle_proofs.append(proof.span());

    let mut input_amounts = ArrayTrait::new();
    input_amounts.append(input_amount);

    let mut input_secrets = ArrayTrait::new();
    input_secrets.append(input_secret);

    let mut input_nullifiers = ArrayTrait::new();
    input_nullifiers.append(input_note.nullifier);

    let mut input_indices = ArrayTrait::new();
    input_indices.append(input_index);

    let mut output_amounts = ArrayTrait::new();
    output_amounts.append(output1_amount);
    output_amounts.append(output2_amount);

    let mut output_secrets = ArrayTrait::new();
    output_secrets.append(output1_secret);
    output_secrets.append(output2_secret);

    let mut output_nullifiers_arr = ArrayTrait::new();
    output_nullifiers_arr.append(output1_nullifier);
    output_nullifiers_arr.append(output2_nullifier);

    match safe_dispatcher.transfer(
        nullifiers.span(),
        output_commitments.span(),
        merkle_proofs.span(),
        input_amounts.span(),
        input_secrets.span(),
        input_nullifiers.span(),
        input_indices.span(),
        output_amounts.span(),
        output_secrets.span(),
        output_nullifiers_arr.span(),
    ) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Balance mismatch', *panic_data.at(0));
        }
    };
}

#[test]
#[feature("safe_dispatcher")]
fn test_transfer_double_spend_fails() {
    let contract_address = deploy_privacy_pool();
    let dispatcher = IPrivacyPoolDispatcher { contract_address };
    let safe_dispatcher = IPrivacyPoolSafeDispatcher { contract_address };

    // Create and deposit note
    let amount: u64 = 100_000_000;
    let secret: felt252 = 0x111111;
    let index: u256 = 0;
    let note = create_note(amount, secret, index);

    dispatcher.deposit(note.commitment);

    // Create single output matching input
    let output_nullifier: felt252 = 0xaaa;
    let output_commitment = create_commitment(amount, 0x222222, output_nullifier);

    let mut nullifiers = ArrayTrait::new();
    nullifiers.append(note.nullifier);

    let mut output_commitments = ArrayTrait::new();
    output_commitments.append(output_commitment);

    let proof = build_merkle_proof_for_index_0();
    let mut merkle_proofs = ArrayTrait::new();
    merkle_proofs.append(proof.span());

    let mut input_amounts = ArrayTrait::new();
    input_amounts.append(amount);

    let mut input_secrets = ArrayTrait::new();
    input_secrets.append(secret);

    let mut input_nullifiers = ArrayTrait::new();
    input_nullifiers.append(note.nullifier);

    let mut input_indices = ArrayTrait::new();
    input_indices.append(index);

    let mut output_amounts = ArrayTrait::new();
    output_amounts.append(amount);

    let mut output_secrets = ArrayTrait::new();
    output_secrets.append(0x222222);

    let mut output_nullifiers_arr = ArrayTrait::new();
    output_nullifiers_arr.append(output_nullifier);

    // First transfer succeeds
    dispatcher.transfer(
        nullifiers.span(),
        output_commitments.span(),
        merkle_proofs.span(),
        input_amounts.span(),
        input_secrets.span(),
        input_nullifiers.span(),
        input_indices.span(),
        output_amounts.span(),
        output_secrets.span(),
        output_nullifiers_arr.span(),
    );

    // Second transfer with same input should fail
    match safe_dispatcher.transfer(
        nullifiers.span(),
        output_commitments.span(),
        merkle_proofs.span(),
        input_amounts.span(),
        input_secrets.span(),
        input_nullifiers.span(),
        input_indices.span(),
        output_amounts.span(),
        output_secrets.span(),
        output_nullifiers_arr.span(),
    ) {
        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
        Result::Err(panic_data) => {
            assert(*panic_data.at(0) == 'Nullifier already spent', *panic_data.at(0));
        }
    };
}
