# Private Bitcoin Payments MVP - Minimum Viable Product

## Executive Summary

This MVP focuses on delivering core privacy functionality with the simplest possible implementation. The goal is to prove the concept works and gather real user feedback before building the full system.

## MVP Philosophy

**What we're building:**
- A working private payment system that actually protects user privacy
- Enough functionality to be genuinely useful
- A foundation that can scale to the full architecture

**What we're NOT building (yet):**
- Complex mixing protocols
- Multiple bridge options
- Advanced compliance features
- Mobile apps
- High-frequency trading optimizations

## 1. MVP Scope

### 1.1 Core Features (MUST HAVE)

✅ **Shielded Deposits**
- Users can deposit Bitcoin and receive private balance
- Simple custodial bridge (multi-sig wallet)
- Fixed denominations (0.01, 0.1, 1.0 BTC)

✅ **Private Transfers**
- Send shielded tokens to another user
- Hide sender, receiver, and amount
- Zero-knowledge proof verification

✅ **Shielded Withdrawals**
- Convert shielded balance back to Bitcoin
- Withdraw to any Bitcoin address
- Break on-chain link between deposit and withdrawal

✅ **Basic Wallet Interface**
- View shielded balance
- Send/receive private transactions
- Transaction history (local, encrypted)

### 1.2 Features to Defer (LATER)

❌ **Advanced Privacy**
- Mixing protocol (can be added later)
- Decoy transactions
- Advanced anonymity set management

❌ **Complex Bridge**
- Non-custodial bridge (too complex for MVP)
- Multi-chain support
- Instant withdrawals

❌ **Compliance Tools**
- Selective disclosure
- View keys
- Audit reports

❌ **Advanced UX**
- Mobile apps
- Hardware wallet integration
- Multi-currency support

## 2. Technical Architecture (Simplified)

### 2.1 System Components

```
┌─────────────────────────────────────────┐
│     Web Wallet (React + Starknet.js)    │
│  - Balance display                       │
│  - Send/Receive UI                       │
│  - Proof generation                      │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│   Privacy Smart Contracts (Cairo)        │
│  - PrivacyPool.cairo                     │
│  - Verifier.cairo                        │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│        Starknet Sepolia Testnet         │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│    Simple Bridge (Multi-sig BTC Wallet) │
│  - 2-of-3 multi-signature                │
│  - Manual processing initially           │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Bitcoin Testnet                  │
└─────────────────────────────────────────┘
```

### 2.2 Smart Contract Architecture

**Single Main Contract: PrivacyPool.cairo**

```cairo
// Simplified structure
#[starknet::contract]
mod PrivacyPool {
    struct Storage {
        // Merkle tree of commitments
        commitments: LegacyMap<u256, felt252>,
        commitment_count: u256,
        merkle_root: felt252,
        
        // Prevent double-spending
        nullifiers: LegacyMap<felt252, bool>,
        
        // Bridge balances
        total_deposited: u256,
        total_withdrawn: u256,
    }
    
    // Core functions
    fn deposit(commitment: felt252, btc_tx_proof: Array<felt252>)
    fn withdraw(proof: Array<felt252>, nullifier: felt252, recipient: felt252)
    fn transfer(proof: Array<felt252>, nullifiers: Array<felt252>, 
                new_commitments: Array<felt252>)
}
```

## 3. MVP User Flows

### 3.1 Deposit Flow (Simplified)

```
User Journey:
1. User opens web wallet
2. Clicks "Deposit Bitcoin"
3. System generates unique deposit address
4. User sends BTC (0.1 BTC fixed amount for MVP)
5. Waits for 3 confirmations (~30 mins)
6. Bridge operator verifies deposit (manual check initially)
7. Operator submits deposit proof to Starknet
8. Smart contract mints shielded note
9. User's wallet detects the note
10. Balance updates: +0.1 BTC (shielded)

Technical Flow:
1. Generate commitment: C = Hash(amount, secret, nullifier)
2. User sends 0.1 BTC to bridge address
3. Wait for confirmations
4. Bridge calls: deposit(C, btc_tx_hash)
5. Contract adds C to merkle tree
6. Emit event with encrypted note for user
7. User stores note locally
```

### 3.2 Private Transfer Flow

```
User Journey:
1. User enters recipient's stealth address
2. Enters amount (e.g., 0.05 BTC)
3. Clicks "Send Privately"
4. System generates proof (15-30 seconds)
5. Submits transaction to Starknet
6. Confirmation in ~10 seconds
7. Recipient automatically detects payment

Technical Flow:
1. User selects input commitments (0.1 BTC note)
2. Create outputs:
   - 0.05 BTC → recipient commitment
   - 0.05 BTC → change commitment back to sender
3. Generate nullifier for input
4. Create ZK proof proving:
   - User owns input (knows secret)
   - Input = Outputs (0.1 = 0.05 + 0.05)
   - Amounts are valid (range proof)
5. Submit: transfer(proof, [nullifier_in], [commit_out1, commit_out2])
6. Contract verifies proof
7. Marks nullifier as spent
8. Adds new commitments to tree
```

### 3.3 Withdrawal Flow

```
User Journey:
1. User enters Bitcoin address to receive
2. Selects amount to withdraw (e.g., 0.1 BTC)
3. Generates withdrawal proof
4. Submits to Starknet
5. Waits for bridge operator approval (manual initially)
6. Receives Bitcoin in ~1 hour

Technical Flow:
1. User selects commitment to spend
2. Generate withdrawal proof
3. Submit: withdraw(proof, nullifier, btc_address)
4. Contract verifies and marks nullifier spent
5. Bridge operator monitors withdrawal events
6. Operator sends BTC to user's address
7. Updates tracking system
```

## 4. Cryptographic Design (Simplified)

### 4.1 Commitment Scheme

**Simple Pedersen Commitment:**
```
commitment = Pedersen(amount || secret || nullifier)

Where:
- amount: The Bitcoin amount (in satoshis)
- secret: Random 252-bit value (user's private key)
- nullifier: Derived from secret and index
```

**Why this is simple:**
- Use Starknet's built-in Pedersen hash
- No custom curve implementations
- Well-tested and audited

### 4.2 Note Structure

```rust
struct Note {
    commitment: felt252,      // Public (on-chain)
    amount: u64,              // Private (user knows)
    secret: felt252,          // Private (user knows)
    nullifier: felt252,       // Private until spent
    index: u64,               // Position in merkle tree
}
```

### 4.3 Zero-Knowledge Proof (Simplified)

**For MVP, prove just these statements:**

**Transfer Proof:**
```
Public inputs:
- merkle_root
- nullifiers (spent notes)
- new_commitments (new notes)

Private inputs:
- old_amounts, old_secrets
- new_amounts, new_secrets
- merkle_proofs

Constraints:
1. sum(old_amounts) == sum(new_amounts) // Conservation
2. Each old commitment is in merkle tree
3. Each old commitment = Pedersen(old_amount, old_secret, nullifier)
4. Each new commitment = Pedersen(new_amount, new_secret, new_nullifier)
5. All amounts >= 0 and <= max_amount
```

**Implementation:**
- Use Cairo's built-in features
- Keep circuit small (faster proving)
- ~1000-2000 constraints for MVP

## 5. Development Phases

### Phase 1: Foundation (Weeks 1-2)
**Goal:** Basic Cairo contracts working on testnet

**Tasks:**
- [ ] Set up Cairo development environment (Scarb)
- [ ] Implement PrivacyPool contract skeleton
- [ ] Implement Merkle tree operations
- [ ] Write unit tests
- [ ] Deploy to Starknet Sepolia testnet
- [ ] Test deposit/withdrawal manually

**Deliverables:**
- Working Cairo contract on testnet
- Test suite with >80% coverage
- Deployment scripts

### Phase 2: Cryptography (Weeks 3-4)
**Goal:** Working zero-knowledge proofs

**Tasks:**
- [ ] Implement commitment scheme in Cairo
- [ ] Create transfer proof circuit
- [ ] Create withdrawal proof circuit
- [ ] Test proof generation and verification
- [ ] Optimize for performance
- [ ] Security review of crypto code

**Deliverables:**
- Proof generation library
- Proof verification in contract
- Performance benchmarks

### Phase 3: Bridge (Weeks 5-6)
**Goal:** Simple Bitcoin bridge working

**Tasks:**
- [ ] Set up Bitcoin testnet wallet (multi-sig)
- [ ] Create bridge operator scripts
- [ ] Implement deposit detection
- [ ] Implement withdrawal processing
- [ ] Create monitoring dashboard
- [ ] Test end-to-end flows

**Deliverables:**
- Working bridge on testnet
- Operator manual
- Monitoring tools

### Phase 4: Wallet UI (Weeks 7-8)
**Goal:** User-friendly web interface

**Tasks:**
- [ ] Create React app with Starknet.js
- [ ] Implement wallet connection
- [ ] Build deposit interface
- [ ] Build transfer interface
- [ ] Build withdrawal interface
- [ ] Add balance display
- [ ] Local note storage

**Deliverables:**
- Deployed web wallet
- User documentation
- Demo video

### Phase 5: Testing & Launch (Weeks 9-10)
**Goal:** Public testnet release

**Tasks:**
- [ ] End-to-end testing
- [ ] Security audit (basic)
- [ ] Bug fixes
- [ ] Performance optimization
- [ ] User documentation
- [ ] Public testnet launch

**Deliverables:**
- Live MVP on testnet
- User guide
- Bug bounty program (small)

## 6. Technical Specifications

### 6.1 Smart Contract Specs

**Merkle Tree:**
- Depth: 15 levels (32,768 capacity)
- Hash function: Pedersen
- Update strategy: Append-only

**Denominations (Fixed for MVP):**
- 0.01 BTC (1,000,000 sats)
- 0.1 BTC (10,000,000 sats)
- 1.0 BTC (100,000,000 sats)

**Transaction Limits:**
- Max inputs per transaction: 2
- Max outputs per transaction: 2
- Max amount: 1.0 BTC

### 6.2 Bridge Specs

**Bitcoin Side:**
- Network: Testnet (later Mainnet)
- Multi-sig: 2-of-3
- Minimum deposit: 0.01 BTC
- Confirmations required: 3 (testnet), 6 (mainnet)

**Starknet Side:**
- Network: Sepolia (testnet)
- Later: Mainnet
- Gas limit per transaction: 1M steps

### 6.3 Client Specs

**Proof Generation:**
- Target time: <30 seconds
- Browser-based (WASM)
- Fallback: Server-side proving (optional)

**Storage:**
- Notes: IndexedDB (browser)
- Backup: Encrypted JSON export
- No server-side storage

## 7. Security Considerations (MVP)

### 7.1 What We Secure

✅ **Transaction Privacy**
- Sender/receiver anonymity via ZK proofs
- Amount hiding via commitments
- Transaction graph privacy

✅ **Double-Spend Prevention**
- Nullifier tracking
- Merkle tree integrity

✅ **Bridge Security**
- Multi-sig Bitcoin wallet
- Manual verification initially
- Value limits during testing

### 7.2 What We Accept (MVP Trade-offs)

⚠️ **Custodial Risk**
- Bridge operators control Bitcoin
- Mitigated by: trusted operators, multi-sig, value caps
- Plan: Move to non-custodial in v2

⚠️ **Limited Anonymity Set**
- Small user base initially
- Mitigated by: fixed denominations, encourage usage
- Plan: Mixing in v2

⚠️ **Manual Processes**
- Bridge operators manually verify initially
- Mitigated by: clear procedures, multiple operators
- Plan: Automate in v2

### 7.3 Security Checklist

**Before Testnet Launch:**
- [ ] Cairo contract review by 2+ developers
- [ ] Unit test coverage >80%
- [ ] Integration tests for all flows
- [ ] Cryptography review by expert
- [ ] Multi-sig setup tested
- [ ] Emergency pause mechanism

**Before Mainnet (Future):**
- [ ] Professional security audit ($50k+)
- [ ] Formal verification of critical functions
- [ ] Bug bounty program ($25k+)
- [ ] Insurance consideration
- [ ] Gradual value cap increase

## 8. User Experience

### 8.1 Wallet Interface (Wireframe)

```
┌─────────────────────────────────────────┐
│  Private Bitcoin Wallet          [?][⚙] │
├─────────────────────────────────────────┤
│                                          │
│     Shielded Balance                     │
│         0.15 BTC                         │
│                                          │
│  ┌────────────┐  ┌────────────┐         │
│  │  Deposit   │  │  Withdraw  │         │
│  └────────────┘  └────────────┘         │
│                                          │
│  ┌──────────────────────────────┐       │
│  │ Send to:                     │       │
│  │ [________________]           │       │
│  │                              │       │
│  │ Amount: [____] BTC           │       │
│  │                              │       │
│  │        [Send Privately]      │       │
│  └──────────────────────────────┘       │
│                                          │
│  Recent Activity                         │
│  • Received 0.10 BTC - 2 hours ago      │
│  • Sent 0.05 BTC - 1 day ago            │
│                                          │
└─────────────────────────────────────────┘
```

### 8.2 Key User Interactions

**Deposit:**
1. Click "Deposit"
2. Select amount (0.01, 0.1, or 1.0 BTC)
3. See QR code + address
4. Send Bitcoin
5. Wait for confirmation (progress bar)
6. Balance updates

**Send:**
1. Enter recipient address
2. Enter amount
3. Click "Send Privately"
4. See "Generating proof..." (progress)
5. Confirm transaction
6. See success message

**Withdraw:**
1. Click "Withdraw"
2. Enter Bitcoin address
3. Enter amount
4. Confirm
5. Wait for processing
6. Receive confirmation

### 8.3 Error Handling

**Clear Error Messages:**
- "Insufficient balance" → Show current balance
- "Invalid address" → Show format example
- "Proof generation failed" → Retry button
- "Transaction failed" → Show error details + support link

## 9. Success Metrics

### 9.1 Technical Metrics

**Performance:**
- Proof generation: <30 seconds ✓
- Transaction confirmation: <1 minute ✓
- Uptime: >99% ✓

**Security:**
- Zero privacy leaks ✓
- Zero double-spends ✓
- Zero bridge hacks ✓

### 9.2 User Metrics

**Adoption (Testnet):**
- 100+ unique users
- 500+ shielded transactions
- 10+ BTC deposited

**Experience:**
- <5% error rate
- Positive user feedback
- <10% support tickets

## 10. Go-to-Market Strategy

### 10.1 Launch Phases

**Closed Alpha (2 weeks):**
- Internal team testing (5-10 people)
- Fix critical bugs
- Refine UX

**Open Testnet (4 weeks):**
- Public announcement
- Limited to 0.1 BTC per user
- Active support and feedback collection

**Mainnet Beta (8 weeks):**
- Gradual rollout
- Cap at 10 BTC total locked
- Increase limits based on security confidence

### 10.2 Marketing

**Target Audience:**
- Privacy-focused Bitcoin users
- Starknet community
- Crypto developers

**Channels:**
- Twitter/X announcements
- Starknet Discord
- Bitcoin forums (BitcoinTalk)
- Demo videos on YouTube
- Blog posts explaining the tech

**Key Messages:**
- "Private Bitcoin payments on Layer 2"
- "Bank-level privacy with blockchain transparency"
- "No KYC, no tracking, just privacy"

## 11. Resource Requirements

### 11.1 Team

**Minimum Team:**
- 1 Senior Cairo Developer (full-time)
- 1 Full-stack Developer (frontend + backend)
- 1 Cryptography Advisor (part-time)
- 1 DevOps/Bridge Operator (part-time)

**Ideal Team:**
- 2 Cairo Developers
- 1 Full-stack Developer
- 1 Cryptography Expert
- 1 Security Auditor
- 1 DevOps Engineer

### 11.2 Infrastructure

**Development:**
- GitHub repo (free)
- Vercel/Netlify for frontend (free tier)
- Starknet testnet (free)
- Bitcoin testnet (free)

**Testing:**
- Testing server: $50/month
- Monitoring tools: $100/month

**Mainnet (Future):**
- Production servers: $500/month
- Starknet gas: $500-2000/month
- Bitcoin transaction fees: Variable

### 11.3 Budget

**MVP Development (10 weeks):**
- Development: $40k-80k (depending on team)
- Infrastructure: $500
- Testing/QA: $5k
- Security review (basic): $10k
- **Total: ~$55k-95k**

**Mainnet Launch (Additional):**
- Full security audit: $50k-100k
- Bug bounty: $25k-50k
- Legal/compliance: $10k-25k
- Insurance: $10k-30k
- **Total: ~$95k-205k**

## 12. Risks and Mitigations

### 12.1 Technical Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Proof generation too slow | High | Medium | Optimize circuit, use server proving |
| Smart contract bug | Critical | Low | Extensive testing, audit |
| Bridge hack | Critical | Medium | Multi-sig, value caps, manual verification |
| Starknet network issues | Medium | Low | Fallback plans, monitoring |

### 12.2 Business Risks

| Risk | Impact | Probability | Mitigation |
|------|--------|-------------|------------|
| Low user adoption | High | Medium | Strong marketing, easy UX |
| Regulatory issues | High | Low | Start with testnet, monitor regulations |
| Competition | Medium | Medium | Focus on UX and privacy guarantees |
| Funding issues | High | Low | Bootstrap, seek grants |

## 13. What Success Looks Like

**After 10 Weeks (MVP Complete):**
- ✅ Working private payment system on testnet
- ✅ 100+ users testing the system
- ✅ Positive feedback on privacy and UX
- ✅ Zero critical security issues
- ✅ Clear roadmap for mainnet

**After 6 Months (Mainnet Beta):**
- ✅ Deployed on Starknet mainnet
- ✅ 1,000+ users
- ✅ $100k+ TVL
- ✅ Professional security audit passed
- ✅ Active community

**After 1 Year (Growth Phase):**
- ✅ 10,000+ users
- ✅ $1M+ TVL
- ✅ Non-custodial bridge operational
- ✅ Mobile app launched
- ✅ Integration with major wallets

## 14. Next Steps (Week 1 Action Items)

### Immediate Actions:

1. **Set Up Development Environment**
   - [ ] Install Scarb and Cairo toolchain
   - [ ] Create GitHub repository
   - [ ] Set up project structure
   - [ ] Configure testing framework

2. **Design Review**
   - [ ] Review this MVP spec with team
   - [ ] Identify any gaps or concerns
   - [ ] Finalize technical decisions
   - [ ] Create detailed task breakdown

3. **Start Core Development**
   - [ ] Begin PrivacyPool contract
   - [ ] Implement basic Merkle tree
   - [ ] Write first test cases
   - [ ] Set up CI/CD pipeline

4. **Community Engagement**
   - [ ] Create project website/landing page
   - [ ] Write introductory blog post
   - [ ] Join Starknet developer channels
   - [ ] Start building Twitter presence

## 15. Conclusion

This MVP strikes a balance between:
- **Functionality**: Enough features to be useful
- **Simplicity**: Manageable scope for 10 weeks
- **Security**: Safe enough for testnet
- **Scalability**: Foundation for full system

The key insight is that by starting with fixed denominations, a custodial bridge, and basic privacy features, we can prove the concept works and learn from real users before building the complex full system.

**Most Important:** Ship something that actually works and actually provides privacy, even if it's simple. Real user feedback is worth more than perfect architecture.

---

Ready to start building? Begin with Phase 1, Week 1 tasks above! 🚀
