# Bitcoin Collateralized Lending Protocol (BCLP)

A secure, non-custodial lending protocol built on the Stacks blockchain that enables users to leverage Bitcoin holdings as collateral for borrowing stablecoins and other supported assets. Maintains system solvency through algorithmic collateral management and decentralized liquidation mechanisms.

## Features

- **Bitcoin-Backed Collateralization**  
  Native support for BTC collateral with on-chain proof-of-reserve tracking.

- **Dynamic Risk Parameters**  
  - Minimum Collateral Ratio: 150% (configurable)
  - Liquidation Threshold: 120% (configurable)
  - Block-based interest accrual (5% base rate)

- **Decentralized Price Oracles**  
  Admin-managed price feeds with sanity checks:
  ```clarity
  (define-public (update-price-feed (asset (string-ascii 3)) (new-price uint))
  ```

- **Automatic Liquidation Engine**  
  Under-collateralized positions liquidated programmatically:
  ```clarity
  (define-private (liquidate-position (loan-id uint))
  ```

- **Multi-Asset Support**  
  Currently supported assets: `BTC`, `STX`

## Technical Specification

### Core Parameters
| Parameter | Default | Description |
|-----------|---------|-------------|
| `minimum-collateral-ratio` | 150% | Minimum collateralization ratio for new loans |
| `liquidation-threshold` | 120% | Collateral ratio triggering liquidation |
| `platform-fee-rate` | 1% | Protocol revenue fee |

### Loan Structure
```clarity
{
  borrower: principal,
  collateral-amount: uint,  // Satoshi amount
  loan-amount: uint,        // Borrowed amount in microUSD
  interest-rate: uint,      // Annual percentage (APR)
  start-height: uint,       // Stacks block height
  last-interest-calc: uint, // Last updated block
  status: (string-ascii 20) // Active/Repaid/Liquidated
}
```

## Getting Started

### 1. Contract Deployment
```bash
clarinet deploy BCLP
```

### 2. Platform Initialization (Owner Only)
```clarity
(initialize-platform)
```

### 3. Set Initial Price Feeds
```clarity
(update-price-feed "BTC" u50000)  // $50,000/BTC
```

## Core Operations

### Deposit Collateral
```clarity
(deposit-collateral u100000000)  // 1 BTC (in satoshis)
```

### Request Loan (1:2 collateralization example)
```clarity
(request-loan 
  u100000000  // 1 BTC collateral
  u50000      // Request $50,000 loan
)
// Collateral value = 1 * $50,000 = $50,000
// Required collateral = $50,000 * 150% = $75,000
// Loan rejected due to insufficient collateral
```

### Successful Loan Request
```clarity
(request-loan
  u150000000  // 1.5 BTC
  u50000      // $50,000 loan
)
// Collateral value = 1.5 * $50,000 = $75,000
// Required collateral = $50,000 * 150% = $75,000
// Loan approved
```

### Repay Loan
```clarity
(repay-loan 
  u1        // Loan ID
  u52500    // $50,000 principal + $2,500 interest
)
```

## Governance Functions (Owner Only)

### Adjust Risk Parameters
```clarity
(update-collateral-ratio u175)  // Increase to 175%
(update-liquidation-threshold u130)  // New liquidation threshold
```

## API Reference

### Read Functions
| Function | Description |
|----------|-------------|
| `(get-loan-details u1)` | Retrieve full loan details |
| `(get-user-loans 'ST1PQHQKV0RJXZ...)` | List user's active loans |
| `(get-platform-stats)` | System-wide statistics |

## Security Model

### Key Protections
- Price feed sanity checks (`is-valid-price`)
- Collateral ratio validation before loan issuance
- Time-based interest calculation
- Principal-based access control
- Liquidation automation

### Error Codes
| Code | Description |
|------|-------------|
| 100  | Unauthorized access |
| 101  | Insufficient collateral |
| 102  | Below minimum requirement |
| 106  | Invalid liquidation attempt |
| 110  | Invalid price feed |
