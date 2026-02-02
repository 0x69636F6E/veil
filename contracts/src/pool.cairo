/// PrivacyPool contract for the Veil privacy protocol
/// Implements deposit, withdraw, and transfer functionality with Merkle tree commitment storage

#[starknet::interface]
pub trait IPrivacyPool<TContractState> {
    /// Deposit a commitment into the pool
    fn deposit(ref self: TContractState, commitment: felt252);

    /// Withdraw funds from the pool (exits to Bitcoin)
    fn withdraw(
        ref self: TContractState,
        nullifier: felt252,
        withdrawal_amount: u64,
        recipient_address: felt252,
        merkle_proof: Span<felt252>,
        // Private inputs for MVP verification (would be hidden in real ZK proof)
        input_amount: u64,
        input_secret: felt252,
        input_nullifier: felt252,
        input_index: u256,
    );

    /// Transfer funds privately within the pool
    fn transfer(
        ref self: TContractState,
        nullifiers: Span<felt252>,
        output_commitments: Span<felt252>,
        merkle_proofs: Span<Span<felt252>>,
        // Private inputs for MVP verification (would be hidden in real ZK proof)
        input_amounts: Span<u64>,
        input_secrets: Span<felt252>,
        input_nullifiers: Span<felt252>,
        input_indices: Span<u256>,
        output_amounts: Span<u64>,
        output_secrets: Span<felt252>,
        output_nullifiers: Span<felt252>,
    );

    /// Get the current Merkle root
    fn get_merkle_root(self: @TContractState) -> felt252;

    /// Check if a nullifier has been used
    fn is_nullifier_used(self: @TContractState, nullifier: felt252) -> bool;

    /// Get the total number of commitments
    fn get_commitment_count(self: @TContractState) -> u256;

    /// Get a commitment by index
    fn get_commitment(self: @TContractState, index: u256) -> felt252;

    /// Get the total amount deposited
    fn get_total_deposited(self: @TContractState) -> u256;

    /// Get the total amount withdrawn
    fn get_total_withdrawn(self: @TContractState) -> u256;
}

#[starknet::contract]
pub mod PrivacyPool {
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess,
        Map, StorageMapReadAccess, StorageMapWriteAccess
    };
    use super::super::constants::{TREE_DEPTH, get_zero_hash};
    use super::super::merkle::{hash_pair, verify_merkle_proof};
    use super::super::commitment::{create_commitment, compute_nullifier};
    use super::super::note::{MAX_INPUTS, MAX_OUTPUTS, MAX_AMOUNT};

    #[storage]
    struct Storage {
        /// Map of commitment index to commitment value
        commitments: Map<u256, felt252>,
        /// Total number of commitments in the pool
        commitment_count: u256,
        /// Current Merkle root
        merkle_root: felt252,
        /// Filled subtrees for O(depth) insertion (Tornado Cash pattern)
        /// Maps level -> hash of the filled subtree at that level
        filled_subtrees: Map<u8, felt252>,
        /// Map of nullifiers that have been spent
        nullifiers: Map<felt252, bool>,
        /// Total amount deposited (in satoshis)
        total_deposited: u256,
        /// Total amount withdrawn (in satoshis)
        total_withdrawn: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        Deposit: DepositEvent,
        Withdrawal: WithdrawalEvent,
        Transfer: TransferEvent,
    }

    #[derive(Drop, starknet::Event)]
    pub struct DepositEvent {
        #[key]
        pub commitment: felt252,
        pub index: u256,
        pub merkle_root: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WithdrawalEvent {
        #[key]
        pub nullifier: felt252,
        pub amount: u64,
        pub recipient_address: felt252,
        pub merkle_root: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct TransferEvent {
        pub nullifiers: Span<felt252>,
        pub new_commitments: Span<felt252>,
        pub merkle_root: felt252,
    }

    #[constructor]
    fn constructor(ref self: ContractState) {
        // Initialize filled_subtrees with zero hashes at each level
        let mut level: u8 = 0;
        loop {
            if level >= TREE_DEPTH {
                break;
            }
            self.filled_subtrees.write(level, get_zero_hash(level));
            level += 1;
        };

        // Set initial root to the zero tree root (all leaves are zero)
        self.merkle_root.write(get_zero_hash(TREE_DEPTH));
        self.commitment_count.write(0);
        self.total_deposited.write(0);
        self.total_withdrawn.write(0);
    }

    #[abi(embed_v0)]
    impl PrivacyPoolImpl of super::IPrivacyPool<ContractState> {
        fn deposit(ref self: ContractState, commitment: felt252) {
            // Validate commitment is non-zero
            assert(commitment != 0, 'Commitment cannot be zero');

            let index = self.commitment_count.read();

            // Check tree is not full (2^TREE_DEPTH leaves max)
            let max_leaves: u256 = 32768; // 2^15
            assert(index < max_leaves, 'Merkle tree is full');

            // Store the commitment
            self.commitments.write(index, commitment);

            // Insert leaf into Merkle tree and get new root
            let new_root = self._insert_leaf(commitment, index);
            self.merkle_root.write(new_root);

            // Increment commitment count
            self.commitment_count.write(index + 1);

            // Emit deposit event
            self.emit(DepositEvent {
                commitment,
                index,
                merkle_root: new_root,
            });
        }

        fn withdraw(
            ref self: ContractState,
            nullifier: felt252,
            withdrawal_amount: u64,
            recipient_address: felt252,
            merkle_proof: Span<felt252>,
            input_amount: u64,
            input_secret: felt252,
            input_nullifier: felt252,
            input_index: u256,
        ) {
            // 1. Validate nullifier hasn't been used
            assert(!self.nullifiers.read(nullifier), 'Nullifier already spent');

            // 2. Validate recipient address is non-zero
            assert(recipient_address != 0, 'Invalid recipient');

            // 3. Validate amount
            assert(withdrawal_amount > 0, 'Amount must be positive');
            assert(withdrawal_amount <= MAX_AMOUNT, 'Amount exceeds max');
            assert(withdrawal_amount == input_amount, 'Amount mismatch');

            // 4. Verify the commitment is correctly formed
            let computed_commitment = create_commitment(
                input_amount,
                input_secret,
                input_nullifier
            );

            // 5. Verify the nullifier matches
            let computed_nullifier = compute_nullifier(input_secret, input_index);
            assert(computed_nullifier == nullifier, 'Invalid nullifier');

            // 6. Verify commitment exists in Merkle tree
            let current_root = self.merkle_root.read();
            assert(
                verify_merkle_proof(computed_commitment, input_index, merkle_proof, current_root),
                'Invalid merkle proof'
            );

            // 7. Mark nullifier as spent
            self.nullifiers.write(nullifier, true);

            // 8. Update total withdrawn
            let withdrawn: u256 = withdrawal_amount.into();
            self.total_withdrawn.write(self.total_withdrawn.read() + withdrawn);

            // 9. Emit withdrawal event
            self.emit(WithdrawalEvent {
                nullifier,
                amount: withdrawal_amount,
                recipient_address,
                merkle_root: current_root,
            });
        }

        fn transfer(
            ref self: ContractState,
            nullifiers: Span<felt252>,
            output_commitments: Span<felt252>,
            merkle_proofs: Span<Span<felt252>>,
            input_amounts: Span<u64>,
            input_secrets: Span<felt252>,
            input_nullifiers: Span<felt252>,
            input_indices: Span<u256>,
            output_amounts: Span<u64>,
            output_secrets: Span<felt252>,
            output_nullifiers: Span<felt252>,
        ) {
            // 1. Validate input counts
            let num_inputs = nullifiers.len();
            let num_outputs = output_commitments.len();

            assert(num_inputs > 0 && num_inputs <= MAX_INPUTS, 'Invalid input count');
            assert(num_outputs > 0 && num_outputs <= MAX_OUTPUTS, 'Invalid output count');
            assert(num_inputs == input_amounts.len(), 'Input count mismatch');
            assert(num_inputs == merkle_proofs.len(), 'Proof count mismatch');
            assert(num_outputs == output_amounts.len(), 'Output count mismatch');

            let current_root = self.merkle_root.read();

            // 2. Verify and mark all nullifiers
            let mut i: u32 = 0;
            loop {
                if i >= num_inputs {
                    break;
                }

                let nullifier = *nullifiers.at(i);

                // Check nullifier not already spent
                assert(!self.nullifiers.read(nullifier), 'Nullifier already spent');

                // Verify the commitment is correctly formed
                let computed_commitment = create_commitment(
                    *input_amounts.at(i),
                    *input_secrets.at(i),
                    *input_nullifiers.at(i)
                );

                // Verify the nullifier matches
                let computed_nullifier = compute_nullifier(
                    *input_secrets.at(i),
                    *input_indices.at(i)
                );
                assert(computed_nullifier == nullifier, 'Invalid nullifier');

                // Verify commitment exists in Merkle tree
                let proof = *merkle_proofs.at(i);
                assert(
                    verify_merkle_proof(computed_commitment, *input_indices.at(i), proof, current_root),
                    'Invalid merkle proof'
                );

                // Mark nullifier as spent
                self.nullifiers.write(nullifier, true);

                i += 1;
            };

            // 3. Verify output commitments are correctly formed
            let mut j: u32 = 0;
            loop {
                if j >= num_outputs {
                    break;
                }

                let computed_output = create_commitment(
                    *output_amounts.at(j),
                    *output_secrets.at(j),
                    *output_nullifiers.at(j)
                );

                assert(computed_output == *output_commitments.at(j), 'Invalid output commit');
                assert(*output_amounts.at(j) <= MAX_AMOUNT, 'Output exceeds max');

                j += 1;
            };

            // 4. Verify conservation: sum(inputs) == sum(outputs)
            let mut input_sum: u64 = 0;
            let mut k: u32 = 0;
            loop {
                if k >= num_inputs {
                    break;
                }
                input_sum += *input_amounts.at(k);
                k += 1;
            };

            let mut output_sum: u64 = 0;
            let mut l: u32 = 0;
            loop {
                if l >= num_outputs {
                    break;
                }
                output_sum += *output_amounts.at(l);
                l += 1;
            };

            assert(input_sum == output_sum, 'Balance mismatch');

            // 5. Add new commitments to the tree
            let mut new_root = current_root;
            let mut m: u32 = 0;
            loop {
                if m >= num_outputs {
                    break;
                }

                let commitment = *output_commitments.at(m);
                let index = self.commitment_count.read();

                // Check tree is not full
                let max_leaves: u256 = 32768; // 2^15
                assert(index < max_leaves, 'Merkle tree is full');

                // Store the commitment
                self.commitments.write(index, commitment);

                // Insert leaf and update root
                new_root = self._insert_leaf(commitment, index);
                self.merkle_root.write(new_root);

                // Increment count
                self.commitment_count.write(index + 1);

                m += 1;
            };

            // 6. Emit transfer event
            self.emit(TransferEvent {
                nullifiers,
                new_commitments: output_commitments,
                merkle_root: new_root,
            });
        }

        fn get_merkle_root(self: @ContractState) -> felt252 {
            self.merkle_root.read()
        }

        fn is_nullifier_used(self: @ContractState, nullifier: felt252) -> bool {
            self.nullifiers.read(nullifier)
        }

        fn get_commitment_count(self: @ContractState) -> u256 {
            self.commitment_count.read()
        }

        fn get_commitment(self: @ContractState, index: u256) -> felt252 {
            self.commitments.read(index)
        }

        fn get_total_deposited(self: @ContractState) -> u256 {
            self.total_deposited.read()
        }

        fn get_total_withdrawn(self: @ContractState) -> u256 {
            self.total_withdrawn.read()
        }
    }

    #[generate_trait]
    impl InternalFunctions of InternalFunctionsTrait {
        /// Insert a leaf into the Merkle tree using the filled_subtrees pattern
        /// This achieves O(depth) gas cost per insertion
        fn _insert_leaf(ref self: ContractState, leaf: felt252, index: u256) -> felt252 {
            let mut current_hash = leaf;
            let mut current_index = index;
            let mut level: u8 = 0;

            loop {
                if level >= TREE_DEPTH {
                    break;
                }

                // Check if the current position is a left child (even index)
                if current_index % 2 == 0 {
                    // Left child: save current hash as filled subtree
                    // and hash with zero value from right
                    self.filled_subtrees.write(level, current_hash);
                    current_hash = hash_pair(current_hash, get_zero_hash(level));
                } else {
                    // Right child: hash with the filled subtree from left
                    let left_sibling = self.filled_subtrees.read(level);
                    current_hash = hash_pair(left_sibling, current_hash);
                }

                current_index = current_index / 2;
                level += 1;
            };

            current_hash
        }
    }
}
