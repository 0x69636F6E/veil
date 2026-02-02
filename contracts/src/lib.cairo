/// Veil Protocol: Private Bitcoin payment protocol on StarkNet

// Module declarations
pub mod constants;
pub mod merkle;
pub mod commitment;
pub mod note;
pub mod verifier;
pub mod pool;

// Re-export PrivacyPool interface for external use
pub use pool::{IPrivacyPool, IPrivacyPoolDispatcher, IPrivacyPoolDispatcherTrait};
pub use pool::{IPrivacyPoolSafeDispatcher, IPrivacyPoolSafeDispatcherTrait};

// Re-export commitment utilities
pub use commitment::{create_commitment, compute_nullifier, verify_commitment};

// Re-export note types
pub use note::{Note, NoteInput, NoteOutput, create_note, verify_note};

// Keep HelloStarknet for backwards compatibility with existing tests
/// Interface representing `HelloContract`.
/// This interface allows modification and retrieval of the contract balance.
#[starknet::interface]
pub trait IHelloStarknet<TContractState> {
    /// Increase contract balance.
    fn increase_balance(ref self: TContractState, amount: felt252);
    /// Retrieve contract balance.
    fn get_balance(self: @TContractState) -> felt252;
}

/// Simple contract for managing balance.
#[starknet::contract]
mod HelloStarknet {
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    #[storage]
    struct Storage {
        balance: felt252,
    }

    #[abi(embed_v0)]
    impl HelloStarknetImpl of super::IHelloStarknet<ContractState> {
        fn increase_balance(ref self: ContractState, amount: felt252) {
            assert(amount != 0, 'Amount cannot be 0');
            self.balance.write(self.balance.read() + amount);
        }

        fn get_balance(self: @ContractState) -> felt252 {
            self.balance.read()
        }
    }
}
