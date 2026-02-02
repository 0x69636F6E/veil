/// Tests for commitment scheme
use veil::commitment::{
    create_commitment, verify_commitment, compute_nullifier,
    derive_output_nullifier,
    create_commitment_with_domain, COMMITMENT_DOMAIN
};
use veil::note::{create_note, verify_note, MAX_AMOUNT};

#[test]
fn test_create_commitment_deterministic() {
    let amount: u64 = 1_000_000; // 0.01 BTC
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment1 = create_commitment(amount, secret, nullifier);
    let commitment2 = create_commitment(amount, secret, nullifier);

    assert(commitment1 == commitment2, 'Should be deterministic');
}

#[test]
fn test_create_commitment_non_zero() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment = create_commitment(amount, secret, nullifier);
    assert(commitment != 0, 'Commitment non-zero');
}

#[test]
fn test_create_commitment_different_amounts() {
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment1 = create_commitment(1_000_000, secret, nullifier);
    let commitment2 = create_commitment(2_000_000, secret, nullifier);

    assert(commitment1 != commitment2, 'Different amounts differ');
}

#[test]
fn test_create_commitment_different_secrets() {
    let amount: u64 = 1_000_000;
    let nullifier: felt252 = 0x67890;

    let commitment1 = create_commitment(amount, 0x12345, nullifier);
    let commitment2 = create_commitment(amount, 0x54321, nullifier);

    assert(commitment1 != commitment2, 'Different secrets differ');
}

#[test]
fn test_create_commitment_different_nullifiers() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;

    let commitment1 = create_commitment(amount, secret, 0x67890);
    let commitment2 = create_commitment(amount, secret, 0x09876);

    assert(commitment1 != commitment2, 'Different nullifiers');
}

#[test]
fn test_verify_commitment_success() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment = create_commitment(amount, secret, nullifier);
    let is_valid = verify_commitment(commitment, amount, secret, nullifier);

    assert(is_valid, 'Should verify correctly');
}

#[test]
fn test_verify_commitment_wrong_amount() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment = create_commitment(amount, secret, nullifier);
    let is_valid = verify_commitment(commitment, 2_000_000, secret, nullifier);

    assert(!is_valid, 'Wrong amount should fail');
}

#[test]
fn test_verify_commitment_wrong_secret() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let commitment = create_commitment(amount, secret, nullifier);
    let is_valid = verify_commitment(commitment, amount, 0x99999, nullifier);

    assert(!is_valid, 'Wrong secret should fail');
}

#[test]
fn test_compute_nullifier_deterministic() {
    let secret: felt252 = 0x12345;
    let index: u256 = 42;

    let nullifier1 = compute_nullifier(secret, index);
    let nullifier2 = compute_nullifier(secret, index);

    assert(nullifier1 == nullifier2, 'Should be deterministic');
}

#[test]
fn test_compute_nullifier_different_secrets() {
    let index: u256 = 42;

    let nullifier1 = compute_nullifier(0x12345, index);
    let nullifier2 = compute_nullifier(0x54321, index);

    assert(nullifier1 != nullifier2, 'Different secrets differ');
}

#[test]
fn test_compute_nullifier_different_indices() {
    let secret: felt252 = 0x12345;

    let nullifier1 = compute_nullifier(secret, 42);
    let nullifier2 = compute_nullifier(secret, 43);

    assert(nullifier1 != nullifier2, 'Different indices differ');
}

#[test]
fn test_create_note_valid() {
    let amount: u64 = 10_000_000; // 0.1 BTC
    let secret: felt252 = 0xabcdef;
    let index: u256 = 5;

    let note = create_note(amount, secret, index);

    assert(note.amount == amount, 'Amount mismatch');
    assert(note.secret == secret, 'Secret mismatch');
    assert(note.index == index, 'Index mismatch');
    assert(note.commitment != 0, 'Commitment non-zero');
    assert(note.nullifier != 0, 'Nullifier non-zero');
}

#[test]
fn test_verify_note_valid() {
    let amount: u64 = 10_000_000;
    let secret: felt252 = 0xabcdef;
    let index: u256 = 5;

    let note = create_note(amount, secret, index);
    let is_valid = verify_note(@note);

    assert(is_valid, 'Note should be valid');
}

#[test]
fn test_note_nullifier_matches_computed() {
    let amount: u64 = 10_000_000;
    let secret: felt252 = 0xabcdef;
    let index: u256 = 5;

    let note = create_note(amount, secret, index);
    let expected_nullifier = compute_nullifier(secret, index);

    assert(note.nullifier == expected_nullifier, 'Nullifier should match');
}

#[test]
fn test_note_commitment_matches_computed() {
    let amount: u64 = 10_000_000;
    let secret: felt252 = 0xabcdef;
    let index: u256 = 5;

    let note = create_note(amount, secret, index);
    let expected_nullifier = compute_nullifier(secret, index);
    let expected_commitment = create_commitment(amount, secret, expected_nullifier);

    assert(note.commitment == expected_commitment, 'Commitment should match');
}

#[test]
fn test_derive_output_nullifier_unique() {
    let sender_secret: felt252 = 0x12345;
    let recipient1: felt252 = 0xaaa;
    let recipient2: felt252 = 0xbbb;

    let nullifier1 = derive_output_nullifier(sender_secret, recipient1, 0);
    let nullifier2 = derive_output_nullifier(sender_secret, recipient2, 0);

    assert(nullifier1 != nullifier2, 'Different recipients');
}

#[test]
fn test_max_amount_constant() {
    // 1 BTC in satoshis
    assert(MAX_AMOUNT == 100_000_000, 'Max should be 1 BTC');
}

#[test]
fn test_commitment_domain_non_zero() {
    assert(COMMITMENT_DOMAIN != 0, 'Domain should be non-zero');
}

#[test]
fn test_domain_commitment_differs() {
    let amount: u64 = 1_000_000;
    let secret: felt252 = 0x12345;
    let nullifier: felt252 = 0x67890;

    let basic = create_commitment(amount, secret, nullifier);
    let with_domain = create_commitment_with_domain(amount, secret, nullifier);

    assert(basic != with_domain, 'Domain should change hash');
}
