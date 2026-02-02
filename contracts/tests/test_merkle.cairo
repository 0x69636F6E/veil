/// Tests for Merkle tree utilities
use veil::merkle::{hash_pair, get_zero_value_at_level, verify_merkle_proof, compute_root_from_leaf};
use veil::constants::{TREE_DEPTH, ZERO_VALUE, get_zero_hash};

#[test]
fn test_hash_pair_consistency() {
    // Same inputs should always produce the same output
    let left: felt252 = 0x123;
    let right: felt252 = 0x456;

    let hash1 = hash_pair(left, right);
    let hash2 = hash_pair(left, right);

    assert(hash1 == hash2, 'Hash not deterministic');
}

#[test]
fn test_hash_pair_order_matters() {
    // Hash(a, b) != Hash(b, a) for Pedersen
    let a: felt252 = 0x123;
    let b: felt252 = 0x456;

    let hash_ab = hash_pair(a, b);
    let hash_ba = hash_pair(b, a);

    assert(hash_ab != hash_ba, 'Order should matter');
}

#[test]
fn test_hash_pair_non_zero() {
    // Hash of any two values should be non-zero
    let hash = hash_pair(0x1, 0x2);
    assert(hash != 0, 'Hash is zero');

    // Even with zero inputs
    let hash_zeros = hash_pair(0, 0);
    assert(hash_zeros != 0, 'Hash of zeros non-zero');
}

#[test]
fn test_get_zero_value_at_level() {
    // Level 0 should return ZERO_VALUE
    let level_0 = get_zero_value_at_level(0);
    assert(level_0 == ZERO_VALUE, 'Level 0 wrong');

    // All levels should return non-zero values
    let mut level: u8 = 0;
    loop {
        if level > TREE_DEPTH {
            break;
        }
        let zero_hash = get_zero_value_at_level(level);
        assert(zero_hash != 0, 'Zero hash is zero');
        level += 1;
    };
}

#[test]
fn test_zero_hashes_are_different() {
    // Each level should have a different zero hash
    let hash_0 = get_zero_hash(0);
    let hash_1 = get_zero_hash(1);
    let hash_2 = get_zero_hash(2);

    assert(hash_0 != hash_1, 'Level 0 == 1');
    assert(hash_1 != hash_2, 'Level 1 == 2');
    assert(hash_0 != hash_2, 'Level 0 == 2');
}

#[test]
fn test_verify_merkle_proof_single_leaf() {
    // Create a simple proof for a leaf at index 0
    // The proof consists of zero hashes at each level
    let leaf: felt252 = 0x12345;
    let index: u256 = 0;

    // Build proof with zero hashes (all siblings are empty)
    let mut proof_arr = ArrayTrait::new();
    let mut level: u8 = 0;
    loop {
        if level >= TREE_DEPTH {
            break;
        }
        proof_arr.append(get_zero_hash(level));
        level += 1;
    };

    // Compute expected root
    let expected_root = compute_root_from_leaf(leaf, index);

    // Verify the proof
    let is_valid = verify_merkle_proof(leaf, index, proof_arr.span(), expected_root);
    assert(is_valid, 'Valid proof should pass');
}

#[test]
fn test_verify_merkle_proof_wrong_root() {
    let leaf: felt252 = 0x12345;
    let index: u256 = 0;

    // Build proof with zero hashes
    let mut proof_arr = ArrayTrait::new();
    let mut level: u8 = 0;
    loop {
        if level >= TREE_DEPTH {
            break;
        }
        proof_arr.append(get_zero_hash(level));
        level += 1;
    };

    // Use wrong root
    let wrong_root: felt252 = 0xdeadbeef;

    let is_valid = verify_merkle_proof(leaf, index, proof_arr.span(), wrong_root);
    assert(!is_valid, 'Wrong root should fail');
}

#[test]
fn test_verify_merkle_proof_wrong_proof_length() {
    let leaf: felt252 = 0x12345;
    let index: u256 = 0;

    // Build incomplete proof (missing levels)
    let mut proof_arr = ArrayTrait::new();
    proof_arr.append(get_zero_hash(0));
    proof_arr.append(get_zero_hash(1));
    // Only 2 elements instead of TREE_DEPTH

    let any_root: felt252 = 0x123;

    let is_valid = verify_merkle_proof(leaf, index, proof_arr.span(), any_root);
    assert(!is_valid, 'Wrong length should fail');
}

#[test]
fn test_compute_root_from_leaf_different_indices() {
    let leaf: felt252 = 0x12345;

    // Same leaf at different indices should produce different roots
    let root_0 = compute_root_from_leaf(leaf, 0);
    let root_1 = compute_root_from_leaf(leaf, 1);

    assert(root_0 != root_1, 'Same root diff index');
}

#[test]
fn test_tree_depth_constant() {
    assert(TREE_DEPTH == 15, 'Tree depth should be 15');
}
