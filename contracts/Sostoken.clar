;; title: Sostoken
;; version: 1.0.0
;; summary: Emergency SOS Signal Token - Community-driven distress beacon system
;; description: Allows users to create emergency signals that ping the community for help, with token rewards for responders

(define-fungible-token sostoken)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-signal-expired (err u104))
(define-constant err-signal-resolved (err u105))
(define-constant err-already-responded (err u106))
(define-constant err-insufficient-balance (err u107))
(define-constant err-invalid-coordinates (err u108))

(define-data-var total-signals uint u0)
(define-data-var emergency-fee uint u10)
(define-data-var responder-reward uint u50)
(define-data-var signal-duration uint u144)

(define-map sos-signals 
  { signal-id: uint }
  { 
    creator: principal,
    emergency-type: (string-ascii 50),
    description: (string-ascii 200),
    latitude: int,
    longitude: int,
    created-at: uint,
    expires-at: uint,
    status: (string-ascii 20),
    reward-pool: uint,
    response-count: uint
  }
)

(define-map signal-responses
  { signal-id: uint, responder: principal }
  {
    response-message: (string-ascii 200),
    response-type: (string-ascii 30),
    responded-at: uint,
    helpful-votes: uint,
    verified: bool
  }
)

(define-map user-reputation
  { user: principal }
  {
    signals-created: uint,
    responses-given: uint,
    helpful-responses: uint,
    reputation-score: uint,
    last-activity: uint
  }
)

(define-map emergency-contacts
  { user: principal, contact-id: uint }
  {
    contact-principal: principal,
    contact-name: (string-ascii 50),
    priority-level: uint,
    auto-notify: bool
  }
)

(define-read-only (get-name)
  "Sostoken"
)

(define-read-only (get-symbol)
  "SOS"
)

(define-read-only (get-decimals)
  u6
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance sostoken who))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply sostoken))
)

(define-read-only (get-signal (signal-id uint))
  (map-get? sos-signals { signal-id: signal-id })
)

(define-read-only (get-signal-response (signal-id uint) (responder principal))
  (map-get? signal-responses { signal-id: signal-id, responder: responder })
)

(define-read-only (get-user-reputation (user principal))
  (default-to 
    { signals-created: u0, responses-given: u0, helpful-responses: u0, reputation-score: u0, last-activity: u0 }
    (map-get? user-reputation { user: user })
  )
)

(define-read-only (get-emergency-settings)
  {
    emergency-fee: (var-get emergency-fee),
    responder-reward: (var-get responder-reward),
    signal-duration: (var-get signal-duration),
    total-signals: (var-get total-signals)
  }
)

(define-read-only (calculate-reputation-score (signals uint) (responses uint) (helpful uint))
  (+ (* signals u10) (* responses u5) (* helpful u15))
)

(define-read-only (is-signal-active (signal-id uint))
  (match (get-signal signal-id)
    signal-data (< (get expires-at signal-data) stacks-block-height)
    false
  )
)

(define-read-only (get-nearby-signals (lat int) (lng int) (radius uint))
  (let ((signals-list (list)))
    (ok signals-list)
  )
)

(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller)) err-unauthorized)
    (ft-transfer? sostoken amount from to)
  )
)

(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? sostoken amount recipient)
  )
)

(define-public (create-sos-signal 
  (emergency-type (string-ascii 50))
  (description (string-ascii 200))
  (latitude int)
  (longitude int)
  (reward-amount uint))
  (let
    (
      (signal-id (+ (var-get total-signals) u1))
      (current-height stacks-block-height)
      (expires-at (+ current-height (var-get signal-duration)))
      (fee (var-get emergency-fee))
      (total-cost (+ fee reward-amount))
      (sender tx-sender)
    )
    (asserts! (>= (ft-get-balance sostoken sender) total-cost) err-insufficient-balance)
    (asserts! (and (>= latitude (- 90000000)) (<= latitude 90000000)) err-invalid-coordinates)
    (asserts! (and (>= longitude (- 180000000)) (<= longitude 180000000)) err-invalid-coordinates)
    (asserts! (> reward-amount u0) err-invalid-amount)
    
    (try! (ft-burn? sostoken total-cost sender))
    
    (map-set sos-signals 
      { signal-id: signal-id }
      {
        creator: sender,
        emergency-type: emergency-type,
        description: description,
        latitude: latitude,
        longitude: longitude,
        created-at: current-height,
        expires-at: expires-at,
        status: "active",
        reward-pool: reward-amount,
        response-count: u0
      }
    )
    
    (update-user-reputation sender u1 u0 u0)
    (var-set total-signals signal-id)
    (ok signal-id)
  )
)

(define-public (respond-to-signal 
  (signal-id uint)
  (response-message (string-ascii 200))
  (response-type (string-ascii 30)))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (responder tx-sender)
      (current-height stacks-block-height)
    )
    (asserts! (< current-height (get expires-at signal-data)) err-signal-expired)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    (asserts! (not (is-eq responder (get creator signal-data))) err-unauthorized)
    (asserts! (is-none (get-signal-response signal-id responder)) err-already-responded)
    
    (map-set signal-responses
      { signal-id: signal-id, responder: responder }
      {
        response-message: response-message,
        response-type: response-type,
        responded-at: current-height,
        helpful-votes: u0,
        verified: false
      }
    )
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { response-count: (+ (get response-count signal-data) u1) })
    )
    
    (update-user-reputation responder u0 u1 u0)
    (ok true)
  )
)

(define-public (vote-helpful (signal-id uint) (responder principal))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (response-data (unwrap! (get-signal-response signal-id responder) err-not-found))
      (voter tx-sender)
    )
    (asserts! (not (is-eq voter responder)) err-unauthorized)
    (asserts! (is-eq (get creator signal-data) voter) err-unauthorized)
    
    (map-set signal-responses
      { signal-id: signal-id, responder: responder }
      (merge response-data { helpful-votes: (+ (get helpful-votes response-data) u1) })
    )
    
    (update-user-reputation responder u0 u0 u1)
    (ok true)
  )
)

(define-public (resolve-signal (signal-id uint) (successful bool))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (creator (get creator signal-data))
      (reward-pool (get reward-pool signal-data))
    )
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { 
        status: (if successful "resolved" "closed")
      })
    )
    
    (if successful
      (try! (distribute-rewards signal-id reward-pool))
      (try! (ft-mint? sostoken reward-pool creator))
    )
    
    (ok true)
  )
)

(define-public (add-emergency-contact 
  (contact-principal principal)
  (contact-name (string-ascii 50))
  (priority-level uint)
  (auto-notify bool))
  (let
    (
      (user tx-sender)
      (contact-id (get-next-contact-id user))
    )
    (asserts! (<= priority-level u5) err-invalid-amount)
    
    (map-set emergency-contacts
      { user: user, contact-id: contact-id }
      {
        contact-principal: contact-principal,
        contact-name: contact-name,
        priority-level: priority-level,
        auto-notify: auto-notify
      }
    )
    (ok contact-id)
  )
)

(define-public (update-emergency-settings 
  (new-fee uint)
  (new-reward uint)
  (new-duration uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> new-fee u0) err-invalid-amount)
    (asserts! (> new-reward u0) err-invalid-amount)
    (asserts! (> new-duration u0) err-invalid-amount)
    
    (var-set emergency-fee new-fee)
    (var-set responder-reward new-reward)
    (var-set signal-duration new-duration)
    (ok true)
  )
)

(define-public (emergency-mint (recipient principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ft-mint? sostoken amount recipient)
  )
)

(define-private (distribute-rewards (signal-id uint) (total-reward uint))
  (let
    (
      (signal-data (unwrap-panic (get-signal signal-id)))
      (response-count (get response-count signal-data))
    )
    (if (> response-count u0)
      (ft-mint? sostoken total-reward (get creator signal-data))
      (ft-mint? sostoken total-reward (get creator signal-data))
    )
  )
)

(define-private (distribute-to-responders (signal-id uint) (reward-amount uint))
  (ok true)
)

(define-private (update-user-reputation 
  (user principal)
  (signals-increment uint)
  (responses-increment uint)
  (helpful-increment uint))
  (let
    (
      (current-rep (get-user-reputation user))
      (new-signals (+ (get signals-created current-rep) signals-increment))
      (new-responses (+ (get responses-given current-rep) responses-increment))
      (new-helpful (+ (get helpful-responses current-rep) helpful-increment))
      (new-score (calculate-reputation-score new-signals new-responses new-helpful))
    )
    (map-set user-reputation
      { user: user }
      {
        signals-created: new-signals,
        responses-given: new-responses,
        helpful-responses: new-helpful,
        reputation-score: new-score,
        last-activity: stacks-block-height
      }
    )
  )
)

(define-private (get-next-contact-id (user principal))
  u1
)

(define-public (get-active-signals-count)
  (ok (var-get total-signals))
)

(define-public (verify-response (signal-id uint) (responder principal))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (response-data (unwrap! (get-signal-response signal-id responder) err-not-found))
    )
    (asserts! (is-eq tx-sender (get creator signal-data)) err-unauthorized)
    
    (map-set signal-responses
      { signal-id: signal-id, responder: responder }
      (merge response-data { verified: true })
    )
    
    (try! (ft-mint? sostoken (var-get responder-reward) responder))
    (ok true)
  )
)

(define-public (extend-signal (signal-id uint) (additional-blocks uint))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (creator (get creator signal-data))
      (extension-fee (* additional-blocks u2))
    )
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    (asserts! (>= (ft-get-balance sostoken creator) extension-fee) err-insufficient-balance)
    
    (try! (ft-burn? sostoken extension-fee creator))
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { 
        expires-at: (+ (get expires-at signal-data) additional-blocks),
        reward-pool: (+ (get reward-pool signal-data) (/ extension-fee u2))
      })
    )
    (ok true)
  )
)

(define-public (cancel-signal (signal-id uint))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (creator (get creator signal-data))
      (refund-amount (/ (get reward-pool signal-data) u2))
    )
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { status: "cancelled" })
    )
    
    (try! (ft-mint? sostoken refund-amount creator))
    (ok refund-amount)
  )
)

(define-public (escalate-signal (signal-id uint))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (creator (get creator signal-data))
      (escalation-fee u25)
    )
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    (asserts! (>= (ft-get-balance sostoken creator) escalation-fee) err-insufficient-balance)
    
    (try! (ft-burn? sostoken escalation-fee creator))
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { 
        reward-pool: (+ (get reward-pool signal-data) escalation-fee)
      })
    )
    (ok true)
  )
)

(define-public (bulk-notify-contacts (signal-id uint))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (creator (get creator signal-data))
    )
    (asserts! (is-eq tx-sender creator) err-unauthorized)
    (ok true)
  )
)

(define-public (claim-expired-signal (signal-id uint))
  (let
    (
      (signal-data (unwrap! (get-signal signal-id) err-not-found))
      (current-height stacks-block-height)
      (claimer tx-sender)
    )
    (asserts! (>= current-height (get expires-at signal-data)) err-signal-expired)
    (asserts! (is-eq (get status signal-data) "active") err-signal-resolved)
    
    (map-set sos-signals 
      { signal-id: signal-id }
      (merge signal-data { status: "expired" })
    )
    
    (try! (ft-mint? sostoken (/ (get reward-pool signal-data) u4) claimer))
    (ok true)
  )
)

(ft-mint? sostoken u1000000 contract-owner)
