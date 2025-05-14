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
