/// Protocol constants for the Veil privacy pool

/// Merkle tree depth - supports 2^15 = 32,768 commitments
pub const TREE_DEPTH: u8 = 15;

/// Domain-separated zero value for empty leaves
/// This serves as the initial value for empty Merkle tree leaves
pub const ZERO_VALUE: felt252 = 0x5665696c456d707479;  // "VeilEmpty" in hex

/// Fixed denominations in satoshis (1 BTC = 100,000,000 satoshis)
pub const DENOMINATION_001_BTC: u256 = 1_000_000;    // 0.01 BTC
pub const DENOMINATION_01_BTC: u256 = 10_000_000;    // 0.1 BTC
pub const DENOMINATION_1_BTC: u256 = 100_000_000;    // 1.0 BTC

/// Pre-computed zero hashes for each level of the Merkle tree
/// Level 0 is the leaf level, Level 15 is the root
/// Each level's zero hash = Pedersen(zero_hash[level-1], zero_hash[level-1])
/// These placeholder values will be replaced with actual Pedersen computations at runtime
/// or pre-computed offline and hardcoded here
pub fn get_zero_hash(level: u8) -> felt252 {
    // Using distinct placeholder values that fit within felt252 range
    // In production, these should be pre-computed Pedersen hashes
    match level {
        0 => ZERO_VALUE,
        1 => 0x1a2b3c4d5e6f7081,
        2 => 0x2b3c4d5e6f708192,
        3 => 0x3c4d5e6f70819203,
        4 => 0x4d5e6f7081920314,
        5 => 0x5e6f708192032145,
        6 => 0x6f70819203214556,
        7 => 0x7081920321455667,
        8 => 0x8192032145566778,
        9 => 0x9203214556677889,
        10 => 0xa32145566778899a,
        11 => 0xb4215566778899ab,
        12 => 0xc521566778899abc,
        13 => 0xd62156778899abcd,
        14 => 0xe7215678899abcde,
        15 => 0xf821567899abcdef,
        _ => ZERO_VALUE, // Should never happen with valid tree depth
    }
}
