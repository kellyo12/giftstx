;; GiftSTX - A Clarity smart contract for sending and claiming STX gifts
(define-constant ADMIN tx-sender)  ;; Contract owner
(define-data-var gift-counter uint u0)  ;; Tracks gift IDs

;; Mapping: gift ID -> gift details
(define-map gifts 
  { id: uint } 
  (tuple (sender principal) (recipient principal) (amount uint) (message (buff 100)) (claimed bool))
)

;; ------------------- Send a Gift -------------------
(define-public (send-gift (recipient principal) (amount uint) (message (buff 100)))
  (let ((gift-id (+ (var-get gift-counter) u1)))
    (begin
      ;; Validate inputs
      (asserts! (> amount u0) (err u1000))  ;; Ensure non-zero gift
      (asserts! (not (is-eq tx-sender recipient)) (err u1005))  ;; Cannot send gift to self
      (asserts! (<= (len message) u100) (err u1006))  ;; Ensure message is within limits
      
      ;; Transfer STX to contract
      (match (stx-transfer? amount tx-sender (as-contract tx-sender))
        success
          (begin
            (var-set gift-counter gift-id)
            (map-set gifts { id: gift-id } { 
              sender: tx-sender, 
              recipient: recipient, 
              amount: amount, 
              message: message, 
              claimed: false 
            })
            (ok gift-id))
        error (err u1001)
      )
    )
  )
)

;; ------------------- Claim Gift -------------------
(define-public (claim-gift (gift-id uint))
  (let ((gift-opt (map-get? gifts { id: gift-id })))
    (match gift-opt
      gift
        (begin
          ;; Validate claim conditions
          (asserts! (is-eq tx-sender (get recipient gift)) (err u1007))  ;; Must be recipient
          (asserts! (not (get claimed gift)) (err u1008))  ;; Gift must not be claimed
          
          ;; Transfer STX to recipient
          (match (stx-transfer? (get amount gift) (as-contract tx-sender) tx-sender)
            success
              (begin
                (map-set gifts { id: gift-id } (merge gift { claimed: true }))
                (ok true))
            error (err u1002)
          )
        )
      (err u1004)  ;; Gift not found
    )
  )
)

;; ------------------- View Gift -------------------
(define-read-only (get-gift (gift-id uint))
  (match (map-get? gifts { id: gift-id })
    gift (ok (some gift))
    (ok none)
  )
)

;; ------------------- Admin Functions -------------------
(define-public (withdraw-expired-gift (gift-id uint))
  (let ((gift-opt (map-get? gifts { id: gift-id })))
    (begin
      (asserts! (is-eq tx-sender ADMIN) (err u1009))  ;; Only admin can withdraw
      (match gift-opt
        gift
          (begin
            (asserts! (not (get claimed gift)) (err u1010))  ;; Gift must not be claimed
            
            ;; Transfer STX back to sender
            (match (stx-transfer? (get amount gift) (as-contract tx-sender) (get sender gift))
              success
                (begin
                  (map-set gifts { id: gift-id } (merge gift { claimed: true }))
                  (ok true))
              error (err u1011)
            )
          )
        (err u1004)  ;; Gift not found
      )
    )
  )
)