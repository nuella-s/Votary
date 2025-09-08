# Votary - Simplified Decentralized Autonomous Organization (DAO)

Votary is a streamlined Clarity smart contract that provides the foundational building blocks for creating and managing decentralized autonomous organizations (DAOs). It supports membership, proposals, voting, and treasury management, making it a lightweight yet functional governance framework.

---

## Features

### DAO Creation and Management

* Any user can create a new DAO by specifying its name, description, governance token, and membership threshold.
* Each DAO maintains its own governance settings, membership list, proposals, and treasury.
* DAO creators are automatically registered as administrators.

### Membership

* Users can join a DAO directly or by proving token balance against the governance token.
* Members have voting power, which can be based on a default allocation or their token holdings.
* Administrators have special privileges, including updating governance settings and treasury management.

### Governance Settings

* Voting period: Duration of voting on proposals.
* Quorum requirement: Minimum participation threshold.
* Majority threshold: Percentage of votes required for passing.
* Proposal threshold: Minimum voting power required to submit a proposal.

### Proposals

* Members can create proposals if they meet the proposal threshold.
* Proposals include title, description, voting duration, and track votes for and against.
* Voting is time-bound, and outcomes depend on quorum and majority rules.
* Proposals can finalize into "passed" or "rejected" statuses.

### Voting

* Members cast votes for or against proposals with their voting power.
* Each member can vote only once per proposal.
* Vote tallies update dynamically as members participate.

### Treasury

* Each DAO has an on-chain treasury that holds STX.
* Members (admins only) can add or transfer funds.
* Treasury data includes balance and last update timestamp.

### Read-only Queries

* Fetch DAO information (`get-dao-info`).
* Retrieve governance settings (`get-governance-info`).
* View proposal details (`get-proposal-info`).
* Check member details (`get-member-info`).
* Inspect treasury balance (`get-treasury-info`).
* Track individual votes (`get-vote-info`).
* Get the next available DAO ID (`get-next-dao-id`).

---

## Error Handling

The contract uses clear error codes for better debugging:

* `ERR-NOT-FOUND` – DAO, proposal, or member does not exist.
* `ERR-UNAUTHORIZED` – Caller lacks permission.
* `ERR-INVALID-PARAMS` – Invalid or missing input parameters.
* `ERR-INSUFFICIENT-BALANCE` – Not enough tokens or treasury funds.
* `ERR-DAO-INACTIVE` – DAO is inactive.
* `ERR-VOTING-ENDED` – Voting has already ended.
* `ERR-ALREADY-VOTED` – Voter has already cast their ballot.

---

## Key Workflows

1. **Creating a DAO**

   * Call `create-dao` with DAO details.
   * DAO creator is registered as admin with management rights.

2. **Joining a DAO**

   * Use `join-dao` to join without token balance verification.
   * Use `join-dao-with-token` to join with governance token verification.

3. **Submitting a Proposal**

   * Call `create-proposal` with a title and description if membership threshold is met.

4. **Voting**

   * Members cast votes via `vote-on-proposal`.
   * Voting ends automatically when the voting period expires.

5. **Finalizing a Proposal**

   * After voting ends, call `finalize-proposal` to determine outcome.

6. **Treasury Management**

   * Add funds with `add-treasury-funds`.
   * Admins can distribute funds using `transfer-treasury-funds`.

---

## Summary

Votary provides a simplified but complete DAO framework with core governance features: creating DAOs, managing memberships, submitting and voting on proposals, and handling DAO treasury. It balances usability and decentralization, making it ideal for lightweight governance systems.
