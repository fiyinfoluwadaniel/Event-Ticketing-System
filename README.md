# Event Ticketing System

A decentralized event ticketing platform built on Stacks blockchain using Clarity smart contracts.

## System Overview

This system consists of five interconnected smart contracts that handle the complete lifecycle of event tickets:

1. **Ticket Issuance Contract** (`ticket-issuance.clar`) - Creates unique event admission tokens
2. **Transfer Verification Contract** (`transfer-verification.clar`) - Validates legitimate ticket resales
3. **Entry Validation Contract** (`entry-validation.clar`) - Confirms ticket authenticity at venue
4. **Refund Processing Contract** (`refund-processing.clar`) - Handles cancellation and return policies
5. **Capacity Management Contract** (`capacity-management.clar`) - Prevents overselling and manages attendance

## Key Features

- **Unique Ticket Generation**: Each ticket has a unique ID and cannot be duplicated
- **Secure Transfers**: Built-in verification system for legitimate resales
- **Venue Authentication**: Real-time ticket validation at entry points
- **Flexible Refunds**: Automated refund processing based on event policies
- **Capacity Control**: Prevents overselling with real-time attendance tracking

## Contract Architecture

### Ticket Issuance Contract
- Issues tickets with unique identifiers
- Tracks ticket ownership and metadata
- Manages event details and pricing
- Handles initial ticket sales

### Transfer Verification Contract
- Validates ticket transfer requests
- Prevents fraudulent resales
- Maintains transfer history
- Enforces transfer fees and limits

### Entry Validation Contract
- Verifies ticket authenticity at venue
- Prevents double-entry attempts
- Tracks entry timestamps
- Manages venue access control

### Refund Processing Contract
- Processes refund requests
- Calculates refund amounts based on policies
- Handles cancellation scenarios
- Manages refund timelines

### Capacity Management Contract
- Tracks total event capacity
- Monitors current attendance
- Prevents overselling
- Manages waitlist functionality

## Data Structures

### Ticket Structure
\`\`\`clarity
{
ticket-id: uint,
event-id: uint,
owner: principal,
price: uint,
issued-at: uint,
is-used: bool,
metadata: (string-ascii 256)
}
\`\`\`

### Event Structure
\`\`\`clarity
{
event-id: uint,
name: (string-ascii 100),
venue: (string-ascii 100),
date: uint,
capacity: uint,
price: uint,
organizer: principal,
is-active: bool
}
\`\`\`

## Usage Examples

### Creating an Event
\`\`\`clarity
(contract-call? .ticket-issuance create-event
"Concert 2024"
"Madison Square Garden"
u1704067200
u10000
u50000000)
\`\`\`

### Purchasing a Ticket
\`\`\`clarity
(contract-call? .ticket-issuance purchase-ticket u1)
\`\`\`

### Transferring a Ticket
\`\`\`clarity
(contract-call? .transfer-verification transfer-ticket
u1
'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7)
\`\`\`

### Validating Entry
\`\`\`clarity
(contract-call? .entry-validation validate-entry u1)
\`\`\`

### Requesting Refund
\`\`\`clarity
(contract-call? .refund-processing request-refund u1)
\`\`\`

## Testing

Run the test suite using:
\`\`\`bash
npm test
\`\`\`

## Deployment

1. Install Clarinet CLI
2. Run \`clarinet check\` to validate contracts
3. Deploy using \`clarinet deploy\`

## Security Considerations

- All contracts include proper access controls
- Ticket uniqueness is enforced at the blockchain level
- Transfer validation prevents common attack vectors
- Refund policies are immutable once set
- Capacity limits are strictly enforced

## License

MIT License
