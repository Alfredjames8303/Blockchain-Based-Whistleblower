;; Anonymous Tip Validation System
;; Allows community members to validate anonymous tips before escalation to full cases

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-TIP-NOT-FOUND (err u201))
(define-constant ERR-INVALID-TIP (err u202))
(define-constant ERR-ALREADY-VALIDATED (err u203))
(define-constant ERR-TIP-EXPIRED (err u204))
(define-constant ERR-INSUFFICIENT-VALIDATORS (err u205))
(define-constant ERR-INVALID-THRESHOLD (err u206))

;; Tip status constants
(define-constant TIP-STATUS-SUBMITTED u1)
(define-constant TIP-STATUS-VALIDATING u2)
(define-constant TIP-STATUS-APPROVED u3)
(define-constant TIP-STATUS-REJECTED u4)

;; Data variables
(define-data-var tip-count uint u0)
(define-data-var validation-threshold uint u3)
(define-data-var tip-expiry-blocks uint u1008) ;; ~1 week
(define-data-var validator-count uint u0)

;; Maps
(define-map anonymous-tips
  { tip-id: uint }
  {
    content-hash: (buff 32),
    category: (string-utf8 50),
    severity: uint,
    submission-block: uint,
    status: uint,
    validation-count: uint,
    approval-count: uint,
    rejection-count: uint
  }
)

(define-map community-validators
  { validator: principal }
  { 
    active: bool,
    validation-reputation: uint,
    total-validations: uint
  }
)

(define-map tip-validations
  { tip-id: uint, validator: principal }
  {
    validation: bool, ;; true = approve, false = reject
    reasoning-hash: (buff 32),
    timestamp: uint
  }
)

(define-map validator-performance
  { validator: principal }
  {
    correct-validations: uint,
    total-validations: uint,
    accuracy-score: uint
  }
)

;; Public functions

;; Submit anonymous tip for community validation
(define-public (submit-anonymous-tip 
    (content-hash (buff 32))
    (category (string-utf8 50))
    (severity uint))
  (let
    ((tip-id (+ (var-get tip-count) u1)))
    (asserts! (> (len content-hash) u0) ERR-INVALID-TIP)
    (asserts! (and (>= severity u1) (<= severity u5)) ERR-INVALID-TIP)
    (asserts! (> (len category) u0) ERR-INVALID-TIP)
    
    (map-set anonymous-tips
      { tip-id: tip-id }
      {
        content-hash: content-hash,
        category: category,
        severity: severity,
        submission-block: stacks-block-height,
        status: TIP-STATUS-SUBMITTED,
        validation-count: u0,
        approval-count: u0,
        rejection-count: u0
      }
    )
    
    (var-set tip-count tip-id)
    (ok tip-id)
  )
)

;; Add community validator
(define-public (add-validator (validator principal))
  (begin
    (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
    (map-set community-validators
      { validator: validator }
      {
        active: true,
        validation-reputation: u100,
        total-validations: u0
      }
    )
    (var-set validator-count (+ (var-get validator-count) u1))
    (ok true)
  )
)

;; Validate a tip
(define-public (validate-tip 
    (tip-id uint) 
    (validation bool) 
    (reasoning-hash (buff 32)))
  (let
    ((tip-data (unwrap! (map-get? anonymous-tips { tip-id: tip-id }) ERR-TIP-NOT-FOUND))
     (validator-data (unwrap! (map-get? community-validators { validator: tx-sender }) ERR-NOT-AUTHORIZED))
     (existing-validation (map-get? tip-validations { tip-id: tip-id, validator: tx-sender })))
    
    (asserts! (get active validator-data) ERR-NOT-AUTHORIZED)
    (asserts! (is-none existing-validation) ERR-ALREADY-VALIDATED)
    (asserts! (< stacks-block-height (+ (get submission-block tip-data) (var-get tip-expiry-blocks))) ERR-TIP-EXPIRED)
    (asserts! (not (is-eq (get status tip-data) TIP-STATUS-APPROVED)) ERR-ALREADY-VALIDATED)
    (asserts! (not (is-eq (get status tip-data) TIP-STATUS-REJECTED)) ERR-ALREADY-VALIDATED)
    
    ;; Record validation
    (map-set tip-validations
      { tip-id: tip-id, validator: tx-sender }
      {
        validation: validation,
        reasoning-hash: reasoning-hash,
        timestamp: stacks-block-height
      }
    )
    
    ;; Update tip validation counts
    (let
      ((new-validation-count (+ (get validation-count tip-data) u1))
       (new-approval-count (if validation (+ (get approval-count tip-data) u1) (get approval-count tip-data)))
       (new-rejection-count (if validation (get rejection-count tip-data) (+ (get rejection-count tip-data) u1))))
      
      (map-set anonymous-tips
        { tip-id: tip-id }
        (merge tip-data {
          validation-count: new-validation-count,
          approval-count: new-approval-count,
          rejection-count: new-rejection-count,
          status: (if (>= new-validation-count (var-get validation-threshold))
                    (if (> new-approval-count new-rejection-count) TIP-STATUS-APPROVED TIP-STATUS-REJECTED)
                    TIP-STATUS-VALIDATING)
        })
      )
      
      ;; Update validator stats
      (map-set community-validators
        { validator: tx-sender }
        (merge validator-data {
          total-validations: (+ (get total-validations validator-data) u1)
        })
      )
      
      (ok true)
    )
  )
)

;; Set validation threshold
(define-public (set-validation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-threshold u2) (<= new-threshold u10)) ERR-INVALID-THRESHOLD)
    (var-set validation-threshold new-threshold)
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-tip (tip-id uint))
  (map-get? anonymous-tips { tip-id: tip-id })
)

(define-read-only (get-tip-validation (tip-id uint) (validator principal))
  (map-get? tip-validations { tip-id: tip-id, validator: validator })
)

(define-read-only (is-validator (principal-check principal))
  (default-to false (get active (map-get? community-validators { validator: principal-check })))
)

(define-read-only (get-validation-threshold)
  (var-get validation-threshold)
)

(define-read-only (get-tip-count)
  (var-get tip-count)
)

(define-read-only (get-validator-stats (validator principal))
  (map-get? community-validators { validator: validator })
)
