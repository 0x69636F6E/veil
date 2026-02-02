/// Merkle tree utilities for the Veil privacy pool
use core::pedersen::PedersenTrait;
use core::hash::HashStateTrait;
use super::constants::{TREE_DEPTH, get_zero_hash};

/// Compute Pedersen hash of two field elements
/// Used for combining child nodes in the Merkle tree
pub fn hash_pair(left: felt252, right: felt252) -> felt252 {
    PedersenTrait::new(left).update(right).finalize()
}

/// Get the zero value at a specific level of the Merkle tree
/// Level 0 is the leaf level
pub fn get_zero_value_at_level(level: u8) -> felt252 {
    get_zero_hash(level)
}

/// Verify a Merkle proof
/// - leaf: The leaf value to verify
/// - index: The index of the leaf (determines left/right at each level)
/// - proof: Array of sibling hashes from leaf to root
/// - root: The expected Merkle root
/// Returns true if the proof is valid
pub fn verify_merkle_proof(
    leaf: felt252,
    index: u256,
    proof: Span<felt252>,
    root: felt252
) -> bool {
    // Proof length must match tree depth
    if proof.len() != TREE_DEPTH.into() {
        return false;
    }

    let mut current_hash = leaf;
    let mut current_index = index;
    let mut i: u32 = 0;

    loop {
        if i >= TREE_DEPTH.into() {
            break;
        }

        let sibling = *proof.at(i);

        // If index is even, current node is on the left
        // If index is odd, current node is on the right
        if current_index % 2 == 0 {
            current_hash = hash_pair(current_hash, sibling);
        } else {
            current_hash = hash_pair(sibling, current_hash);
        }

        current_index = current_index / 2;
        i += 1;
    };

    current_hash == root
}

/// Compute the root of a Merkle tree from a single leaf at a given index
/// using zero values for all other positions
/// This is useful for computing the initial root or verifying sparse trees
pub fn compute_root_from_leaf(leaf: felt252, index: u256) -> felt252 {
    let mut current_hash = leaf;
    let mut current_index = index;
    let mut level: u8 = 0;

    loop {
        if level >= TREE_DEPTH {
            break;
        }

        let sibling = get_zero_hash(level);

        if current_index % 2 == 0 {
            current_hash = hash_pair(current_hash, sibling);
        } else {
            current_hash = hash_pair(sibling, current_hash);
        }

        current_index = current_index / 2;
        level += 1;
    };

    current_hash
}
