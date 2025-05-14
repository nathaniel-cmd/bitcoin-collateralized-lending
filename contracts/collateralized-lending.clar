;; Title: Bitcoin Collateralized Lending Protocol (BCLP)
;;
;; A secure, compliant lending protocol built on Stacks that allows users to 
;; use their Bitcoin as collateral to borrow stablecoins or other assets.
;;
;; The protocol maintains appropriate collateral ratios, calculates interest
;; based on time (block height), and includes liquidation mechanisms to
;; ensure the system remains solvent even during market volatility.
;;

;; Constants

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-COLLATERAL (err u101))
(define-constant ERR-BELOW-MINIMUM (err u102))
(define-constant ERR-INVALID-AMOUNT (err u103))
(define-constant ERR-ALREADY-INITIALIZED (err u104))
(define-constant ERR-NOT-INITIALIZED (err u105))
(define-constant ERR-INVALID-LIQUIDATION (err u106))
(define-constant ERR-LOAN-NOT-FOUND (err u107))
(define-constant ERR-LOAN-NOT-ACTIVE (err u108))
(define-constant ERR-INVALID-LOAN-ID (err u109))
(define-constant ERR-INVALID-PRICE (err u110))
(define-constant ERR-INVALID-ASSET (err u111))

;; Platform constants
(define-constant VALID-ASSETS (list "BTC" "STX"))

;; Data Variables

;; Platform state
(define-data-var platform-initialized bool false)
(define-data-var minimum-collateral-ratio uint u150) ;; 150% collateral ratio
(define-data-var liquidation-threshold uint u120) ;; 120% triggers liquidation
(define-data-var platform-fee-rate uint u1) ;; 1% platform fee
(define-data-var total-btc-locked uint u0)
(define-data-var total-loans-issued uint u0)

;; Data Maps

;; Loan details storage
(define-map loans
  
{ loan-id: uint }
  
{
  
  borrower: principal,
  
  collateral-amount: uint,
  
  loan-amount: uint,
  
  interest-rate: uint,
  
  start-height: uint,
  
  last-interest-calc: uint,
  
  status: (string-ascii 20),
  
}

)

;; Track loans by user
(define-map user-loans
  
{ user: principal }
  
{ active-loans: (list 10 uint) }

)

;; Price oracle data
(define-map collateral-prices
  
{ asset: (string-ascii 3) }
  
{ price: uint }

)

;; Private Functions

;; Calculate the current collateral-to-loan ratio as a percentage
(define-private (calculate-collateral-ratio
    (collateral uint)
    (loan uint)
    (btc-price uint)
  )
  (let (
      (collateral-value (* collateral btc-price))
      (ratio (* (/ collateral-value loan) u100))
    )
    ratio
  )
)

;; Calculate interest accrued over a period of blocks
(define-private (calculate-interest
    (principal uint)
    (rate uint)
    (blocks uint)
  )
  (let (
      ;; Daily interest divided by blocks per day (144 blocks = 1 day)
      (interest-per-block (/ (* principal rate) (* u100 u144)))
      (total-interest (* interest-per-block blocks))
    )
    total-interest
  )
)

;; Check if a loan position needs to be liquidated
(define-private (check-liquidation (loan-id uint))
  (let (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (btc-price (unwrap! (get price (map-get? collateral-prices { asset: "BTC" }))
        ERR-NOT-INITIALIZED
      ))
      (current-ratio (calculate-collateral-ratio (get collateral-amount loan)
        (get loan-amount loan) btc-price
      ))
    )
    (if (<= current-ratio (var-get liquidation-threshold))
      (liquidate-position loan-id)
      (ok true)
    )
  )
)

;; Process liquidation of an under-collateralized position
(define-private (liquidate-position (loan-id uint))
  (let (
      (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
      (borrower (get borrower loan))
    )
    (begin
      (map-set loans { loan-id: loan-id } (merge loan { status: "liquidated" }))
      (map-delete user-loans { user: borrower })
      (ok true)
    )
  )
)

;; Validate that a loan ID exists within the system
(define-private (validate-loan-id (loan-id uint))
  (and
    (> loan-id u0)
    (<= loan-id (var-get total-loans-issued))
  )
)

;; Check if an asset is supported by the protocol
(define-private (is-valid-asset (asset (string-ascii 3)))
  (is-some (index-of VALID-ASSETS asset))
)

;; Ensure price data is within reasonable bounds
(define-private (is-valid-price (price uint))
  (and
    (> price u0)
    (<= price u1000000000000) ;; Reasonable upper limit for price
  )
)

;; Helper function for filtering loan IDs
(define-private (not-equal-loan-id (id uint))
  (not (is-eq id id))
)

;; Public Functions: Platform Management

;; Initialize the lending platform (one-time operation)
(define-public (initialize-platform)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get platform-initialized)) ERR-ALREADY-INITIALIZED)
    (var-set platform-initialized true)
    (ok true)
  )
)

;; Public Functions: Lending Operations

;; Deposit Bitcoin collateral into the protocol
(define-public (deposit-collateral (amount uint))
  (begin
    (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (var-set total-btc-locked (+ (var-get total-btc-locked) amount))
    (ok true)
  )
)

;; Request a loan against deposited collateral
(define-public (request-loan
    (collateral uint)
    (loan-amount uint)
  )
  (let (
      (btc-price (unwrap! (get price (map-get? collateral-prices { asset: "BTC" }))
        ERR-NOT-INITIALIZED
      ))
      (collateral-value (* collateral btc-price))
      (required-collateral (* loan-amount (var-get minimum-collateral-ratio)))
      (loan-id (+ (var-get total-loans-issued) u1))
    )
    (begin
      (asserts! (var-get platform-initialized) ERR-NOT-INITIALIZED)
      (asserts! (>= collateral-value required-collateral)
        ERR-INSUFFICIENT-COLLATERAL
      )
      ;; Create the loan record
      (map-set loans { loan-id: loan-id } {
        borrower: tx-sender,
        collateral-amount: collateral,
        loan-amount: loan-amount,
        interest-rate: u5, ;; 5% interest rate
        start-height: stacks-block-height,
        last-interest-calc: stacks-block-height,
        status: "active",
      })
      ;; Update user's active loans list
      (match (map-get? user-loans { user: tx-sender })
        existing-loans (map-set user-loans { user: tx-sender } { active-loans: (unwrap!
          (as-max-len? (append (get active-loans existing-loans) loan-id) u10)
          ERR-INVALID-AMOUNT
        ) }
        )
        (map-set user-loans { user: tx-sender } { active-loans: (list loan-id) })
      )
      (var-set total-loans-issued (+ (var-get total-loans-issued) u1))
      (ok loan-id)
    )
  )
)

;; Repay an outstanding loan with interest
(define-public (repay-loan
    (loan-id uint)
    (amount uint)
  )
  (begin
    (asserts! (validate-loan-id loan-id) ERR-INVALID-LOAN-ID)
    (let (
        (loan (unwrap! (map-get? loans { loan-id: loan-id }) ERR-LOAN-NOT-FOUND))
        (interest-owed (calculate-interest (get loan-amount loan) (get interest-rate loan)
          (- stacks-block-height (get last-interest-calc loan))
        ))
        (total-owed (+ (get loan-amount loan) interest-owed))
      )
      (begin
        (asserts! (is-eq (get status loan) "active") ERR-LOAN-NOT-ACTIVE)
        (asserts! (is-eq (get borrower loan) tx-sender) ERR-NOT-AUTHORIZED)
        (asserts! (>= amount total-owed) ERR-INVALID-AMOUNT)
        ;; Update loan status
        (map-set loans { loan-id: loan-id }
          (merge loan {
            status: "repaid",
            last-interest-calc: stacks-block-height,
          })
        )
        ;; Release collateral
        (var-set total-btc-locked
          (- (var-get total-btc-locked) (get collateral-amount loan))
        )
        ;; Remove from user's active loans
        (match (map-get? user-loans { user: tx-sender })
          existing-loans (ok (map-set user-loans { user: tx-sender } { active-loans: (filter not-equal-loan-id (get active-loans existing-loans)) }))
          (ok false)
        )
      )
    )
  )
)

;; Public Functions: Governance

;; Update the minimum collateral ratio (admin only)
(define-public (update-collateral-ratio (new-ratio uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-ratio u110) ERR-INVALID-AMOUNT)
    (var-set minimum-collateral-ratio new-ratio)
    (ok true)
  )
)

;; Update the liquidation threshold (admin only)
(define-public (update-liquidation-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-threshold u110) ERR-INVALID-AMOUNT)
    (var-set liquidation-threshold new-threshold)
    (ok true)
  )
)

;; Update asset price feed (admin only)
(define-public (update-price-feed
    (asset (string-ascii 3))
    (new-price uint)
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-asset asset) ERR-INVALID-ASSET)
    (asserts! (is-valid-price new-price) ERR-INVALID-PRICE)
    (ok (map-set collateral-prices { asset: asset } { price: new-price }))
  )
)

;; Read-Only Functions

;; Get details for a specific loan
(define-read-only (get-loan-details (loan-id uint))
  (map-get? loans { loan-id: loan-id })
)

;; Get all active loans for a user
(define-read-only (get-user-loans (user principal))
  (map-get? user-loans { user: user })
)

;; Get overall platform statistics
(define-read-only (get-platform-stats)
  {
    total-btc-locked: (var-get total-btc-locked),
    total-loans-issued: (var-get total-loans-issued),
    minimum-collateral-ratio: (var-get minimum-collateral-ratio),
    liquidation-threshold: (var-get liquidation-threshold),
  }
)

;; Get list of supported assets
(define-read-only (get-valid-assets)
  VALID-ASSETS
)
