;; Simplified Decentralized Autonomous Organization (DAO)
;; Core functionality with membership management, proposals, and voting

;; Define SIP-010 fungible token trait
(define-trait sip-010-trait
  (
    ;; Transfer from the caller to a new principal
    (transfer (uint principal principal (optional (buff 34))) (response bool uint))
    ;; the human readable name of the token
    (get-name () (response (string-ascii 32) uint))
    ;; the ticker symbol, or empty if none
    (get-symbol () (response (string-ascii 32) uint))
    ;; the number of decimals used, e.g. 6 would mean 1_000_000 represents 1 token
    (get-decimals () (response uint uint))
    ;; the balance of the passed principal
    (get-balance (principal) (response uint uint))
    ;; the current total supply (which does not need to be a constant)
    (get-total-supply () (response uint uint))
    ;; an optional URI that represents metadata of this token
    (get-token-uri () (response (optional (string-utf8 256)) uint))
  )
)

;; Error constants
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-PARAMS (err u400))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-DAO-INACTIVE (err u403))
(define-constant ERR-VOTING-ENDED (err u405))
(define-constant ERR-ALREADY-VOTED (err u406))

;; DAO basic information
(define-map daos
  { dao-id: uint }
  {
    name: (string-utf8 64),
    description: (string-utf8 256),
    creator: principal,
    created-at: uint,
    governance-token: principal,
    membership-threshold: uint,
    active: bool
  }
)

;; DAO governance settings
(define-map governance-settings
  { dao-id: uint }
  {
    voting-period: uint,
    voting-quorum: uint,
    majority-threshold: uint,
    proposal-threshold: uint
  }
)

;; DAO members
(define-map members
  { dao-id: uint, member: principal }
  {
    joined-at: uint,
    active: bool,
    is-admin: bool,
    voting-power: uint
  }
)

;; Proposals
(define-map proposals
  { dao-id: uint, proposal-id: uint }
  {
    title: (string-utf8 128),
    description: (string-utf8 512),
    proposer: principal,
    created-at: uint,
    voting-ends-at: uint,
    status: (string-ascii 16),
    votes-for: uint,
    votes-against: uint,
    total-votes: uint
  }
)

;; Votes cast
(define-map votes
  { dao-id: uint, proposal-id: uint, voter: principal }
  {
    vote-for: bool,
    voting-power: uint,
    timestamp: uint
  }
)

;; Treasury balances
(define-map treasury
  { dao-id: uint }
  {
    stx-balance: uint,
    last-updated: uint
  }
)

;; Counters
(define-data-var next-dao-id uint u1)
(define-map next-proposal-id { dao-id: uint } { id: uint })

;; Helper functions
(define-private (is-valid-dao-id (dao-id uint))
  (is-some (map-get? daos { dao-id: dao-id }))
)

(define-private (is-dao-active (dao-id uint))
  (match (map-get? daos { dao-id: dao-id })
    dao-data (get active dao-data)
    false
  )
)

(define-private (is-member (dao-id uint) (user principal))
  (match (map-get? members { dao-id: dao-id, member: user })
    member-data (get active member-data)
    false
  )
)

(define-private (is-admin (dao-id uint) (user principal))
  (match (map-get? members { dao-id: dao-id, member: user })
    member-data (and (get active member-data) (get is-admin member-data))
    false
  )
)

;; Create a new DAO
(define-public (create-dao
                (name (string-utf8 64))
                (description (string-utf8 256))
                (governance-token principal)
                (membership-threshold uint))
  (let ((dao-id (var-get next-dao-id)))
    
    ;; Validate parameters
    (asserts! (> membership-threshold u0) ERR-INVALID-PARAMS)
    (asserts! (> (len name) u0) ERR-INVALID-PARAMS)
    
    ;; Create DAO
    (map-set daos
      { dao-id: dao-id }
      {
        name: name,
        description: description,
        creator: tx-sender,
        created-at: block-height,
        governance-token: governance-token,
        membership-threshold: membership-threshold,
        active: true
      }
    )
    
    ;; Set default governance settings
    (map-set governance-settings
      { dao-id: dao-id }
      {
        voting-period: u1440,    ;; ~10 days
        voting-quorum: u2000,    ;; 20%
        majority-threshold: u5000, ;; 50%
        proposal-threshold: membership-threshold
      }
    )
    
    ;; Initialize treasury
    (map-set treasury
      { dao-id: dao-id }
      {
        stx-balance: u0,
        last-updated: block-height
      }
    )
    
    ;; Add creator as admin member
    (map-set members
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: true,
        voting-power: u0
      }
    )
    
    ;; Initialize proposal counter
    (map-set next-proposal-id { dao-id: dao-id } { id: u0 })
    
    ;; Increment DAO counter
    (var-set next-dao-id (+ dao-id u1))
    
    (ok dao-id)
  )
)

;; Join DAO as member (simplified without token balance check)
(define-public (join-dao (dao-id uint))
  (let ((dao-data (unwrap! (map-get? daos { dao-id: dao-id }) ERR-NOT-FOUND)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-DAO-INACTIVE)
    (asserts! (not (is-member dao-id tx-sender)) ERR-INVALID-PARAMS)
    
    ;; Add member with basic voting power
    (map-set members
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: false,
        voting-power: u1000000 ;; Default voting power
      }
    )
    
    (ok true)
  )
)

;; Join DAO with token balance check
(define-public (join-dao-with-token (dao-id uint) (token-balance uint))
  (let ((dao-data (unwrap! (map-get? daos { dao-id: dao-id }) ERR-NOT-FOUND)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-DAO-INACTIVE)
    (asserts! (>= token-balance (get membership-threshold dao-data)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (not (is-member dao-id tx-sender)) ERR-INVALID-PARAMS)
    
    ;; Add member
    (map-set members
      { dao-id: dao-id, member: tx-sender }
      {
        joined-at: block-height,
        active: true,
        is-admin: false,
        voting-power: token-balance
      }
    )
    
    (ok true)
  )
)

;; Update governance settings (admin only)
(define-public (update-governance-settings
                (dao-id uint)
                (voting-period uint)
                (voting-quorum uint)
                (majority-threshold uint)
                (proposal-threshold uint))
  (begin
    ;; Validate
    (asserts! (is-valid-dao-id dao-id) ERR-NOT-FOUND)
    (asserts! (is-dao-active dao-id) ERR-DAO-INACTIVE)
    (asserts! (is-admin dao-id tx-sender) ERR-UNAUTHORIZED)
    (asserts! (and (> voting-period u0) (<= voting-quorum u10000) (<= majority-threshold u10000)) ERR-INVALID-PARAMS)
    
    ;; Update settings
    (map-set governance-settings
      { dao-id: dao-id }
      {
        voting-period: voting-period,
        voting-quorum: voting-quorum,
        majority-threshold: majority-threshold,
        proposal-threshold: proposal-threshold
      }
    )
    
    (ok true)
  )
)

;; Create proposal
(define-public (create-proposal
                (dao-id uint)
                (title (string-utf8 128))
                (description (string-utf8 512)))
  (let ((dao-data (unwrap! (map-get? daos { dao-id: dao-id }) ERR-NOT-FOUND))
        (settings (unwrap! (map-get? governance-settings { dao-id: dao-id }) ERR-NOT-FOUND))
        (member-data (unwrap! (map-get? members { dao-id: dao-id, member: tx-sender }) ERR-UNAUTHORIZED))
        (proposal-counter (unwrap! (map-get? next-proposal-id { dao-id: dao-id }) ERR-NOT-FOUND))
        (proposal-id (get id proposal-counter)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-DAO-INACTIVE)
    (asserts! (get active member-data) ERR-UNAUTHORIZED)
    (asserts! (>= (get voting-power member-data) (get proposal-threshold settings)) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> (len title) u0) ERR-INVALID-PARAMS)
    
    ;; Create proposal
    (map-set proposals
      { dao-id: dao-id, proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        created-at: block-height,
        voting-ends-at: (+ block-height (get voting-period settings)),
        status: "active",
        votes-for: u0,
        votes-against: u0,
        total-votes: u0
      }
    )
    
    ;; Increment proposal counter
    (map-set next-proposal-id
      { dao-id: dao-id }
      { id: (+ proposal-id u1) }
    )
    
    (ok proposal-id)
  )
)

;; Vote on proposal
(define-public (vote-on-proposal
                (dao-id uint)
                (proposal-id uint)
                (vote-for bool))
  (let ((dao-data (unwrap! (map-get? daos { dao-id: dao-id }) ERR-NOT-FOUND))
        (proposal (unwrap! (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id }) ERR-NOT-FOUND))
        (member-data (unwrap! (map-get? members { dao-id: dao-id, member: tx-sender }) ERR-UNAUTHORIZED))
        (voting-power (get voting-power member-data)))
    
    ;; Validate
    (asserts! (get active dao-data) ERR-DAO-INACTIVE)
    (asserts! (get active member-data) ERR-UNAUTHORIZED)
    (asserts! (is-eq (get status proposal) "active") ERR-INVALID-PARAMS)
    (asserts! (< block-height (get voting-ends-at proposal)) ERR-VOTING-ENDED)
    (asserts! (is-none (map-get? votes { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender })) ERR-ALREADY-VOTED)
    (asserts! (> voting-power u0) ERR-INSUFFICIENT-BALANCE)
    
    ;; Record vote
    (map-set votes
      { dao-id: dao-id, proposal-id: proposal-id, voter: tx-sender }
      {
        vote-for: vote-for,
        voting-power: voting-power,
        timestamp: block-height
      }
    )
    
    ;; Update proposal vote counts
    (map-set proposals
      { dao-id: dao-id, proposal-id: proposal-id }
      (merge proposal
        {
          votes-for: (if vote-for (+ (get votes-for proposal) voting-power) (get votes-for proposal)),
          votes-against: (if vote-for (get votes-against proposal) (+ (get votes-against proposal) voting-power)),
          total-votes: (+ (get total-votes proposal) voting-power)
        }
      )
    )
    
    (ok true)
  )
)

;; Finalize proposal
(define-public (finalize-proposal (dao-id uint) (proposal-id uint))
  (let ((proposal (unwrap! (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id }) ERR-NOT-FOUND))
        (settings (unwrap! (map-get? governance-settings { dao-id: dao-id }) ERR-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-eq (get status proposal) "active") ERR-INVALID-PARAMS)
    (asserts! (>= block-height (get voting-ends-at proposal)) ERR-VOTING-ENDED)
    
    ;; Calculate results
    (let ((total-supply u100000000) ;; Simplified total supply
          (quorum-met (>= (get total-votes proposal) (/ (* total-supply (get voting-quorum settings)) u10000)))
          (majority-met (>= (get votes-for proposal) (/ (* (get total-votes proposal) (get majority-threshold settings)) u10000))))
      
      ;; Update proposal status
      (map-set proposals
        { dao-id: dao-id, proposal-id: proposal-id }
        (merge proposal
          {
            status: (if (and quorum-met majority-met) "passed" "rejected")
          }
        )
      )
      
      (ok (and quorum-met majority-met))
    )
  )
)

;; Add funds to treasury
(define-public (add-treasury-funds (dao-id uint) (amount uint))
  (let ((treasury-data (unwrap! (map-get? treasury { dao-id: dao-id }) ERR-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-valid-dao-id dao-id) ERR-NOT-FOUND)
    (asserts! (is-dao-active dao-id) ERR-DAO-INACTIVE)
    (asserts! (> amount u0) ERR-INVALID-PARAMS)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    
    ;; Update treasury
    (map-set treasury
      { dao-id: dao-id }
      {
        stx-balance: (+ (get stx-balance treasury-data) amount),
        last-updated: block-height
      }
    )
    
    (ok true)
  )
)

;; Transfer funds from treasury (admin only)
(define-public (transfer-treasury-funds (dao-id uint) (recipient principal) (amount uint))
  (let ((treasury-data (unwrap! (map-get? treasury { dao-id: dao-id }) ERR-NOT-FOUND)))
    
    ;; Validate
    (asserts! (is-valid-dao-id dao-id) ERR-NOT-FOUND)
    (asserts! (is-dao-active dao-id) ERR-DAO-INACTIVE)
    (asserts! (is-admin dao-id tx-sender) ERR-UNAUTHORIZED)
    (asserts! (>= (get stx-balance treasury-data) amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-PARAMS)
    
    ;; Transfer STX
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update treasury
    (map-set treasury
      { dao-id: dao-id }
      {
        stx-balance: (- (get stx-balance treasury-data) amount),
        last-updated: block-height
      }
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-dao-info (dao-id uint))
  (map-get? daos { dao-id: dao-id })
)

(define-read-only (get-proposal-info (dao-id uint) (proposal-id uint))
  (map-get? proposals { dao-id: dao-id, proposal-id: proposal-id })
)

(define-read-only (get-member-info (dao-id uint) (member principal))
  (map-get? members { dao-id: dao-id, member: member })
)

(define-read-only (get-treasury-info (dao-id uint))
  (map-get? treasury { dao-id: dao-id })
)

(define-read-only (get-governance-info (dao-id uint))
  (map-get? governance-settings { dao-id: dao-id })
)

(define-read-only (get-vote-info (dao-id uint) (proposal-id uint) (voter principal))
  (map-get? votes { dao-id: dao-id, proposal-id: proposal-id, voter: voter })
)

(define-read-only (get-next-dao-id)
  (var-get next-dao-id)
)