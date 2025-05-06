
;; title: Blockchain-Based-Whistleblower
;; version:
;; summary:
;; description:
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CASE-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))
(define-constant ERR-ALREADY-VOTED (err u103))
(define-constant ERR-INVALID-VOTE (err u104))
(define-constant ERR-INVALID-EVIDENCE (err u105))
(define-constant ERR-INVALID-REPORT (err u106))
(define-constant ERR-CASE-CLOSED (err u107))
(define-constant ERR-INVALID-REWARD (err u108))

(define-constant STATUS-PENDING u1)
(define-constant STATUS-UNDER-REVIEW u2)
(define-constant STATUS-RESOLVED u3)
(define-constant STATUS-REJECTED u4)

(define-constant VOTE-VALID u1)
(define-constant VOTE-INVALID u2)

(define-data-var case-count uint u0)
(define-data-var admin principal tx-sender)
(define-data-var reviewers-count uint u0)

(define-map cases
  { case-id: uint }
  {
    title: (string-utf8 100),
    description: (string-utf8 500),
    evidence-hash: (buff 32),
    status: uint,
    timestamp: uint,
    category: (string-utf8 50),
    severity: uint,
    reward-amount: uint,
    valid-votes: uint,
    invalid-votes: uint,
    resolution-details: (optional (string-utf8 500))
  }
)

(define-map case-reporters
  { case-id: uint }
  { commitment-hash: (buff 32) }
)

(define-map reviewers
  { reviewer: principal }
  { active: bool }
)

(define-map reviewer-votes
  { case-id: uint, reviewer: principal }
  { vote: uint }
)

(define-map case-evidence
  { case-id: uint, evidence-id: uint }
  { 
    evidence-hash: (buff 32),
    description: (string-utf8 100),
    timestamp: uint
  }
)

(define-map case-evidence-count
  { case-id: uint }
  { count: uint }
)

(define-map case-comments
  { case-id: uint, comment-id: uint }
  {
    author: principal,
    content: (string-utf8 200),
    timestamp: uint
  }
)

(define-map case-comments-count
  { case-id: uint }
  { count: uint }
)

(define-read-only (get-case (case-id uint))
  (map-get? cases { case-id: case-id })
)

(define-read-only (get-case-reporter (case-id uint))
  (map-get? case-reporters { case-id: case-id })
)

(define-read-only (get-case-count)
  (var-get case-count)
)

(define-read-only (is-reviewer (reviewer principal))
  (default-to false (get active (map-get? reviewers { reviewer: reviewer })))
)

(define-read-only (get-reviewer-vote (case-id uint) (reviewer principal))
  (map-get? reviewer-votes { case-id: case-id, reviewer: reviewer })
)

(define-read-only (get-case-evidence (case-id uint) (evidence-id uint))
  (map-get? case-evidence { case-id: case-id, evidence-id: evidence-id })
)

(define-read-only (get-case-evidence-count (case-id uint))
  (default-to { count: u0 } (map-get? case-evidence-count { case-id: case-id }))
)

(define-read-only (get-case-comment (case-id uint) (comment-id uint))
  (map-get? case-comments { case-id: case-id, comment-id: comment-id })
)

(define-read-only (get-case-comments-count (case-id uint))
  (default-to { count: u0 } (map-get? case-comments-count { case-id: case-id }))
)

(define-public (submit-anonymous-report 
    (title (string-utf8 100))
    (description (string-utf8 500))
    (evidence-hash (buff 32))
    (commitment-hash (buff 32))
    (category (string-utf8 50))
    (severity uint))
  (let
    (
      (case-id (+ (var-get case-count) u1))
    )
    (asserts! (> (len evidence-hash) u0) ERR-INVALID-EVIDENCE)
    (asserts! (> (len title) u0) ERR-INVALID-REPORT)
    (asserts! (> (len description) u0) ERR-INVALID-REPORT)
    (asserts! (and (>= severity u1) (<= severity u5)) ERR-INVALID-REPORT)
    
    (map-set cases
      { case-id: case-id }
      {
        title: title,
        description: description,
        evidence-hash: evidence-hash,
        status: STATUS-PENDING,
        timestamp: stacks-block-height,
        category: category,
        severity: severity,
        reward-amount: u0,
        valid-votes: u0,
        invalid-votes: u0,
        resolution-details: none
      }
    )
    
    (map-set case-reporters
      { case-id: case-id }
      { commitment-hash: commitment-hash }
    )
    
    (map-set case-evidence-count
      { case-id: case-id }
      { count: u0 }
    )
    
    (map-set case-comments-count
      { case-id: case-id }
      { count: u0 }
    )
    
    (var-set case-count case-id)
    (ok case-id)
  )
)

(define-public (add-evidence (case-id uint) (evidence-hash (buff 32)) (description (string-utf8 100)))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
      (evidence-count (get count (get-case-evidence-count case-id)))
      (new-evidence-id (+ evidence-count u1))
    )
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    (asserts! (not (is-eq (get status case-data) STATUS-REJECTED)) ERR-CASE-CLOSED)
    (asserts! (> (len evidence-hash) u0) ERR-INVALID-EVIDENCE)
    
    (map-set case-evidence
      { case-id: case-id, evidence-id: new-evidence-id }
      {
        evidence-hash: evidence-hash,
        description: description,
        timestamp: stacks-block-height
      }
    )
    
    (map-set case-evidence-count
      { case-id: case-id }
      { count: new-evidence-id }
    )
    
    (ok new-evidence-id)
  )
)

(define-public (add-comment (case-id uint) (content (string-utf8 200)))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
      (comments-count (get count (get-case-comments-count case-id)))
      (new-comment-id (+ comments-count u1))
    )
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    (asserts! (not (is-eq (get status case-data) STATUS-REJECTED)) ERR-CASE-CLOSED)
    (asserts! (> (len content) u0) ERR-INVALID-REPORT)
    
    (map-set case-comments
      { case-id: case-id, comment-id: new-comment-id }
      {
        author: tx-sender,
        content: content,
        timestamp: stacks-block-height
      }
    )
    
    (map-set case-comments-count
      { case-id: case-id }
      { count: new-comment-id }
    )
    
    (ok new-comment-id)
  )
)

(define-public (add-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (map-set reviewers
      { reviewer: reviewer }
      { active: true }
    )
    (var-set reviewers-count (+ (var-get reviewers-count) u1))
    (ok true)
  )
)

(define-public (remove-reviewer (reviewer principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (is-reviewer reviewer) ERR-NOT-AUTHORIZED)
    (map-set reviewers
      { reviewer: reviewer }
      { active: false }
    )
    (var-set reviewers-count (- (var-get reviewers-count) u1))
    (ok true)
  )
)

(define-public (change-case-status (case-id uint) (new-status uint))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-status STATUS-PENDING) (<= new-status STATUS-REJECTED)) ERR-INVALID-STATUS)
    
    (map-set cases
      { case-id: case-id }
      (merge case-data { status: new-status })
    )
    
    (ok true)
  )
)

(define-public (vote-on-case (case-id uint) (vote uint))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
      (reviewer-vote (get-reviewer-vote case-id tx-sender))
    )
    (asserts! (is-reviewer tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-none reviewer-vote) ERR-ALREADY-VOTED)
    (asserts! (or (is-eq vote VOTE-VALID) (is-eq vote VOTE-INVALID)) ERR-INVALID-VOTE)
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    (asserts! (not (is-eq (get status case-data) STATUS-REJECTED)) ERR-CASE-CLOSED)
    
    (map-set reviewer-votes
      { case-id: case-id, reviewer: tx-sender }
      { vote: vote }
    )
    
    (if (is-eq vote VOTE-VALID)
      (map-set cases
        { case-id: case-id }
        (merge case-data { valid-votes: (+ (get valid-votes case-data) u1) })
      )
      (map-set cases
        { case-id: case-id }
        (merge case-data { invalid-votes: (+ (get invalid-votes case-data) u1) })
      )
    )
    
    (ok true)
  )
)

(define-public (resolve-case (case-id uint) (resolution-details (string-utf8 500)) (reward-amount uint))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    (asserts! (not (is-eq (get status case-data) STATUS-REJECTED)) ERR-CASE-CLOSED)
    (asserts! (>= (get valid-votes case-data) (get invalid-votes case-data)) ERR-INVALID-REPORT)
    
    (map-set cases
      { case-id: case-id }
      (merge case-data { 
        status: STATUS-RESOLVED,
        resolution-details: (some resolution-details),
        reward-amount: reward-amount
      })
    )
    
    (ok true)
  )
)

(define-public (reject-case (case-id uint) (resolution-details (string-utf8 500)))
  (let
    (
      (case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    (asserts! (not (is-eq (get status case-data) STATUS-REJECTED)) ERR-CASE-CLOSED)
    
    (map-set cases
      { case-id: case-id }
      (merge case-data { 
        status: STATUS-REJECTED,
        resolution-details: (some resolution-details)
      })
    )
    
    (ok true)
  )
)

(define-public (transfer-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (var-set admin new-admin)
    (ok true)
  )
)


(define-constant ERR-INVALID-PROOF (err u109))
(define-constant ERR-ALREADY-CLAIMED (err u110))

(define-map reward-claims
  { case-id: uint }
  { claimed: bool }
)

(define-public (claim-reward 
    (case-id uint) 
    (original-secret (buff 32))
    (proof-data (buff 32)))
  (let
    ((case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
     (reporter-data (unwrap! (get-case-reporter case-id) ERR-CASE-NOT-FOUND))
     (claim-status (default-to { claimed: false } (map-get? reward-claims { case-id: case-id }))))
    
    (asserts! (is-eq (get status case-data) STATUS-RESOLVED) ERR-INVALID-STATUS)
    (asserts! (not (get claimed claim-status)) ERR-ALREADY-CLAIMED)
    (asserts! (is-eq (hash160 (concat original-secret proof-data)) 
                     (get commitment-hash reporter-data)) 
              ERR-INVALID-PROOF)

    (map-set reward-claims
      { case-id: case-id }
      { claimed: true })

    (as-contract
      (stx-transfer? (get reward-amount case-data) tx-sender 'ST000000000000000000002AMW42H))
    )
)


(define-public (get-case-status (case-id uint))
  (let
    ((case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND)))
    (ok (get status case-data))
  )
)


(define-constant ERR-NOT-DELEGATE (err u111))

(define-map case-delegates
  { case-id: uint }
  { delegate: principal }
)

(define-public (delegate-case (case-id uint) (delegate-address principal))
  (let
    ((case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND)))
    
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    
    (map-set case-delegates
      { case-id: case-id }
      { delegate: delegate-address })
    
    (ok true)))

(define-read-only (get-case-delegate (case-id uint))
  (map-get? case-delegates { case-id: case-id }))

(define-public (delegate-resolve-case 
    (case-id uint) 
    (resolution-details (string-utf8 500)) 
    (reward-amount uint))
  (let
    ((case-data (unwrap! (get-case case-id) ERR-CASE-NOT-FOUND))
     (delegate-data (unwrap! (get-case-delegate case-id) ERR-NOT-DELEGATE)))
    
    (asserts! (is-eq tx-sender (get delegate delegate-data)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status case-data) STATUS-RESOLVED)) ERR-CASE-CLOSED)
    
    (map-set cases
      { case-id: case-id }
      (merge case-data { 
        status: STATUS-RESOLVED,
        resolution-details: (some resolution-details),
        reward-amount: reward-amount
      }))
    
    (ok true)))