/// Note structure for the Veil privacy protocol
/// A Note represents a private balance that can be spent
use super::commitment::{create_commitment, compute_nullifier};

/// Note represents a private balance owned by a user
/// Only the owner knows all the fields; the commitment is public
#[derive(Drop, Copy, Serde)]
pub struct Note {
    /// The public commitment stored in the Merkle tree
    pub commitment: felt252,
    /// The amount in satoshis (private, known only to owner)
    pub amount: u64,
    /// Random secret known only to the owner
    pub secret: felt252,
    /// Nullifier secret (derived from secret and index)
    pub nullifier: felt252,
    /// Position in the Merkle tree
    pub index: u256,
}

/// NoteInput represents a note being spent in a transaction
#[derive(Drop, Copy, Serde)]
pub struct NoteInput {
    /// The note being spent
    pub note: Note,
    /// Merkle proof showing the commitment is in the tree
    pub merkle_proof: Span<felt252>,
}

/// NoteOutput represents a new note being created
#[derive(Drop, Copy, Serde)]
pub struct NoteOutput {
    /// The new commitment (will be added to Merkle tree)
    pub commitment: felt252,
    /// The amount being sent (private)
    pub amount: u64,
    /// Encrypted note data for the recipient
    pub encrypted_note: felt252,
}

/// Create a new Note from its components
pub fn create_note(
    amount: u64,
    secret: felt252,
    index: u256
) -> Note {
    // Compute the nullifier for this note
    let nullifier = compute_nullifier(secret, index);

    // Compute the commitment
    let commitment = create_commitment(amount, secret, nullifier);

    Note {
        commitment,
        amount,
        secret,
        nullifier,
        index,
    }
}

/// Verify that a Note is correctly formed
pub fn verify_note(note: @Note) -> bool {
    // Recompute the nullifier
    let computed_nullifier = compute_nullifier(*note.secret, *note.index);
    if computed_nullifier != *note.nullifier {
        return false;
    }

    // Recompute the commitment
    let computed_commitment = create_commitment(*note.amount, *note.secret, computed_nullifier);
    if computed_commitment != *note.commitment {
        return false;
    }

    true
}

/// Get the nullifier that will be published when spending this note
pub fn get_spend_nullifier(note: @Note) -> felt252 {
    *note.nullifier
}

/// Maximum number of inputs per transaction
pub const MAX_INPUTS: u32 = 2;

/// Maximum number of outputs per transaction
pub const MAX_OUTPUTS: u32 = 2;

/// Maximum amount in a single note (1 BTC in satoshis)
pub const MAX_AMOUNT: u64 = 100_000_000;
