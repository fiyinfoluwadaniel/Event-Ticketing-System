;; Ticket Issuance Contract
;; Creates unique event admission tokens

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-EVENT (err u101))
(define-constant ERR-EVENT-INACTIVE (err u102))
(define-constant ERR-INSUFFICIENT-PAYMENT (err u103))
(define-constant ERR-CAPACITY-EXCEEDED (err u104))
(define-constant ERR-TICKET-NOT-FOUND (err u105))

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var next-ticket-id uint u1)

;; Data Maps
(define-map events uint {
  name: (string-ascii 100),
  venue: (string-ascii 100),
  date: uint,
  capacity: uint,
  price: uint,
  organizer: principal,
  is-active: bool,
  tickets-sold: uint
})

(define-map tickets uint {
  event-id: uint,
  owner: principal,
  price: uint,
  issued-at: uint,
  is-used: bool,
  metadata: (string-ascii 256)
})

(define-map user-tickets principal (list 100 uint))

;; Public Functions

;; Create a new event
(define-public (create-event (name (string-ascii 100)) (venue (string-ascii 100)) (date uint) (capacity uint) (price uint))
  (let ((event-id (var-get next-event-id)))
    (asserts! (> capacity u0) ERR-INVALID-EVENT)
    (asserts! (> price u0) ERR-INVALID-EVENT)
    (asserts! (> date block-height) ERR-INVALID-EVENT)

    (map-set events event-id {
      name: name,
      venue: venue,
      date: date,
      capacity: capacity,
      price: price,
      organizer: tx-sender,
      is-active: true,
      tickets-sold: u0
    })

    (var-set next-event-id (+ event-id u1))
    (ok event-id)
  )
)

;; Purchase a ticket for an event
(define-public (purchase-ticket (event-id uint))
  (let (
    (event (unwrap! (map-get? events event-id) ERR-INVALID-EVENT))
    (ticket-id (var-get next-ticket-id))
    (current-tickets (default-to (list) (map-get? user-tickets tx-sender)))
  )
    (asserts! (get is-active event) ERR-EVENT-INACTIVE)
    (asserts! (< (get tickets-sold event) (get capacity event)) ERR-CAPACITY-EXCEEDED)
    (asserts! (>= (stx-get-balance tx-sender) (get price event)) ERR-INSUFFICIENT-PAYMENT)

    ;; Transfer payment to organizer
    (try! (stx-transfer? (get price event) tx-sender (get organizer event)))

    ;; Create ticket
    (map-set tickets ticket-id {
      event-id: event-id,
      owner: tx-sender,
      price: (get price event),
      issued-at: block-height,
      is-used: false,
      metadata: ""
    })

    ;; Update event tickets sold
    (map-set events event-id (merge event {tickets-sold: (+ (get tickets-sold event) u1)}))

    ;; Update user tickets list
    (map-set user-tickets tx-sender (unwrap! (as-max-len? (append current-tickets ticket-id) u100) ERR-CAPACITY-EXCEEDED))

    (var-set next-ticket-id (+ ticket-id u1))
    (ok ticket-id)
  )
)

;; Deactivate an event (organizer only)
(define-public (deactivate-event (event-id uint))
  (let ((event (unwrap! (map-get? events event-id) ERR-INVALID-EVENT)))
    (asserts! (is-eq tx-sender (get organizer event)) ERR-NOT-AUTHORIZED)

    (map-set events event-id (merge event {is-active: false}))
    (ok true)
  )
)

;; Mark ticket as used (for entry validation)
(define-public (mark-ticket-used (ticket-id uint))
  (let ((ticket (unwrap! (map-get? tickets ticket-id) ERR-TICKET-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner ticket)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-used ticket)) ERR-CAPACITY-EXCEEDED)

    (map-set tickets ticket-id (merge ticket {is-used: true}))
    (ok true)
  )
)

;; Transfer ticket ownership
(define-public (transfer-ticket (ticket-id uint) (new-owner principal))
  (let ((ticket (unwrap! (map-get? tickets ticket-id) ERR-TICKET-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner ticket)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get is-used ticket)) ERR-CAPACITY-EXCEEDED)

    (map-set tickets ticket-id (merge ticket {owner: new-owner}))
    (ok true)
  )
)

;; Read-only Functions

;; Get event details
(define-read-only (get-event (event-id uint))
  (map-get? events event-id)
)

;; Get ticket details
(define-read-only (get-ticket (ticket-id uint))
  (map-get? tickets ticket-id)
)

;; Get user tickets
(define-read-only (get-user-tickets (user principal))
  (default-to (list) (map-get? user-tickets user))
)

;; Check if ticket exists and is valid
(define-read-only (is-valid-ticket (ticket-id uint))
  (match (map-get? tickets ticket-id)
    ticket (and (not (get is-used ticket)) (is-some (map-get? events (get event-id ticket))))
    false
  )
)
