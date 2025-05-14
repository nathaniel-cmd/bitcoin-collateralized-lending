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