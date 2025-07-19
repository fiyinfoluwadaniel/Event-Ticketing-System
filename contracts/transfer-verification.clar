;; Transfer Verification Contract
;; Validates legitimate ticket resales

;; Constants
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-TICKET-NOT-FOUND (err u201))
(define-constant ERR-TICKET-ALREADY-USED (err u202))
(define-constant ERR-INVALID-RECIPIENT (err u203))
(define-constant ERR-TRANSFER-FEE-REQUIRED (err u204))
(define-constant ERR-SAME-OWNER (err u205))

;; Data Variables
(define-data-var transfer-fee-percentage uint u5) ;; 5% transfer fee
(define-data-var next-transfer-id uint u1)
(define-data-var contract-owner principal tx-sender)

;; Data Maps
(define-map transfer-history uint {
  ticket-id: uint,
  from: principal,
  to: principal,
  price: uint,
  fee: uint,
  timestamp: uint
})

(define-map pending-transfers uint {
  ticket-id: uint,
  from: principal,
  to: principal,
  price: uint,
  expires-at: uint
})

(define-map ticket-ownership uint principal)

;; Public Functions

;; Register ticket ownership (called when ticket is created)
(define-public (register-ticket (ticket-id uint) (owner principal))
  (begin
    (map-set ticket-ownership ticket-id owner)
    (ok true)
  )
)

;; Initiate ticket transfer
(define-public (initiate-transfer (ticket-id uint) (recipient principal) (price uint))
  (let (
    (current-owner (unwrap! (map-get? ticket-ownership ticket-id) ERR-TICKET-NOT-FOUND))
    (transfer-id (var-get next-transfer-id))
  )
    (asserts! (is-eq tx-sender current-owner) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq tx-sender recipient)) ERR-SAME-OWNER)
    (asserts! (> price u0) ERR-INVALID-RECIPIENT)

    ;; Create pending transfer (expires in 144 blocks ~ 24 hours)
    (map-set pending-transfers transfer-id {
      ticket-id: ticket-id,
      from: tx-sender,
      to: recipient,
      price: price,
      expires-at: (+ block-height u144)
    })

    (var-set next-transfer-id (+ transfer-id u1))
    (ok transfer-id)
  )
)

;; Complete ticket transfer
(define-public (complete-transfer (transfer-id uint))
  (let (
    (transfer (unwrap! (map-get? pending-transfers transfer-id) ERR-TICKET-NOT-FOUND))
    (fee (/ (* (get price transfer) (var-get transfer-fee-percentage)) u100))
    (seller-amount (- (get price transfer) fee))
  )
    (asserts! (is-eq tx-sender (get to transfer)) ERR-NOT-AUTHORIZED)
    (asserts! (< block-height (get expires-at transfer)) ERR-TICKET-NOT-FOUND)
    (asserts! (>= (stx-get-balance tx-sender) (get price transfer)) ERR-TRANSFER-FEE-REQUIRED)

    ;; Transfer payment to seller
    (try! (stx-transfer? seller-amount tx-sender (get from transfer)))

    ;; Transfer fee to contract owner
    (try! (stx-transfer? fee tx-sender (var-get contract-owner)))

    ;; Update ticket ownership
    (map-set ticket-ownership (get ticket-id transfer) (get to transfer))

    ;; Record transfer history
    (map-set transfer-history (var-get next-transfer-id) {
      ticket-id: (get ticket-id transfer),
      from: (get from transfer),
      to: (get to transfer),
      price: (get price transfer),
      fee: fee,
      timestamp: block-height
    })

    ;; Remove pending transfer
    (map-delete pending-transfers transfer-id)

    (ok true)
  )
)

;; Cancel pending transfer
(define-public (cancel-transfer (transfer-id uint))
  (let ((transfer (unwrap! (map-get? pending-transfers transfer-id) ERR-TICKET-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get from transfer)) ERR-NOT-AUTHORIZED)

    (map-delete pending-transfers transfer-id)
    (ok true)
  )
)

;; Update transfer fee (contract owner only)
(define-public (set-transfer-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u20) ERR-INVALID-RECIPIENT) ;; Max 20% fee

    (var-set transfer-fee-percentage new-fee)
    (ok true)
  )
)

;; Read-only Functions

;; Get pending transfer details
(define-read-only (get-pending-transfer (transfer-id uint))
  (map-get? pending-transfers transfer-id)
)

;; Get transfer history
(define-read-only (get-transfer-history (transfer-id uint))
  (map-get? transfer-history transfer-id)
)

;; Get current transfer fee
(define-read-only (get-transfer-fee)
  (var-get transfer-fee-percentage)
)

;; Check if transfer is valid and not expired
(define-read-only (is-valid-transfer (transfer-id uint))
  (match (map-get? pending-transfers transfer-id)
    transfer (< block-height (get expires-at transfer))
    false
  )
)

;; Get ticket owner
(define-read-only (get-ticket-owner (ticket-id uint))
  (map-get? ticket-ownership ticket-id)
)
