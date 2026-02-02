/// Commitment scheme for the Veil privacy protocol
/// Uses Pedersen hash to create hiding and binding commitments
use core::pedersen::PedersenTrait;
use core::hash::HashStateTrait;

/// Create a commitment from amount, secret, and nullifier
/// commitment = Pedersen(Pedersen(amount, secret), nullifier)
/// This construction ensures all three values are bound to the commitment
pub fn create_commitment(amount: u64, secret: felt252, nullifier: felt252) -> felt252 {
    let amount_felt: felt252 = amount.into();
    // First hash amount and secret
    let inner_hash = PedersenTrait::new(amount_felt).update(secret).finalize();
    // Then hash with nullifier
    PedersenTrait::new(inner_hash).update(nullifier).finalize()
}

/// Verify that a commitment matches the given amount, secret, and nullifier
pub fn verify_commitment(
    commitment: felt252,
    amount: u64,
    secret: felt252,
    nullifier: felt252
) -> bool {
    let computed = create_commitment(amount, secret, nullifier);
    computed == commitment
}

/// Compute the nullifier for a note
/// nullifier = Pedersen(secret, commitment_index)
/// This ensures the nullifier is unique per note and can only be computed by the owner
pub fn compute_nullifier(secret: felt252, commitment_index: u256) -> felt252 {
    let index_low: felt252 = (commitment_index & 0xffffffffffffffffffffffffffffffff_u256).try_into().unwrap();
    let index_high: felt252 = ((commitment_index / 0x100000000000000000000000000000000_u256) & 0xffffffffffffffffffffffffffffffff_u256).try_into().unwrap();

    // Hash secret with both parts of the index
    let hash1 = PedersenTrait::new(secret).update(index_low).finalize();
    PedersenTrait::new(hash1).update(index_high).finalize()
}

/// Compute commitment hash for a transfer output
/// This is used when creating new commitments during transfers
pub fn create_output_commitment(
    amount: u64,
    recipient_secret: felt252,
    output_nullifier: felt252
) -> felt252 {
    create_commitment(amount, recipient_secret, output_nullifier)
}

/// Generate a random-looking nullifier for a new output
/// In production, this would use proper randomness from the client
/// For on-chain use, we derive it deterministically from inputs
pub fn derive_output_nullifier(
    sender_secret: felt252,
    recipient_pubkey: felt252,
    output_index: u32
) -> felt252 {
    let index_felt: felt252 = output_index.into();
    let hash1 = PedersenTrait::new(sender_secret).update(recipient_pubkey).finalize();
    PedersenTrait::new(hash1).update(index_felt).finalize()
}

/// Domain separator for Veil commitments
/// Used to prevent cross-protocol attacks
pub const COMMITMENT_DOMAIN: felt252 = 0x5645494c434f4d4d4954; // "VEILCOMMIT" in hex

/// Create a domain-separated commitment (more secure version)
pub fn create_commitment_with_domain(
    amount: u64,
    secret: felt252,
    nullifier: felt252
) -> felt252 {
    let amount_felt: felt252 = amount.into();
    // Include domain separator in the commitment
    let domain_hash = PedersenTrait::new(COMMITMENT_DOMAIN).update(amount_felt).finalize();
    let with_secret = PedersenTrait::new(domain_hash).update(secret).finalize();
    PedersenTrait::new(with_secret).update(nullifier).finalize()
}
