# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Move language smart contract project for the Sui blockchain that implements a meeting escrow system. The contract enables two users to coordinate meetings with financial commitments.

## Common Development Commands

### Build
```bash
sui move build
```

### Run Tests
```bash
sui move test
```

### Run a Single Test
```bash
sui move test --filter <test_name>
```

## Code Architecture

### Module Structure
The project consists of a single module `meeting_escrow::meeting` located in `sources/meeting_escrow.move` that manages meeting requests with escrow functionality.

### Key Components

1. **MeetingRequest Struct**: A shared object that holds:
   - Meeting participants (user1 and user2)
   - Required amount from each participant
   - User2's deposited balance
   - Meeting status flags (is_active, is_confirmed)

2. **Core Functions**:
   - `create_meeting`: User1 initiates a meeting request
   - `deposit_user2`: User2 deposits their commitment
   - `confirm_meeting`: User1 confirms and pays, completing the escrow
   - `cancel_meeting`: User1 can cancel and refund User2's deposit

3. **Error Handling**: The module defines specific error codes:
   - `EWrongAmount` (0): Payment amount doesn't match requirement
   - `EMeetingNotActive` (1): Operation on inactive meeting
   - `EUnauthorized` (2): Unauthorized user attempting operation
   - `EMeetingAlreadyConfirmed` (3): Attempting to modify confirmed meeting

### Testing Approach
Tests are located in `tests/meeting_escrow_tests.move` and use Sui's test scenario framework. Tests cover:
- Happy path scenarios for all functions
- Authorization checks
- Error conditions and edge cases
- Refund mechanics on cancellation

### Move Edition
The project uses Move 2024.beta edition, which requires:
- Visibility modifiers on struct declarations
- Fully qualified module paths (no Self aliases)
- Location attributes in test expected_failure annotations