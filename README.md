# Blockchain-Based Whistleblower Protection System

A decentralized application built on Stacks blockchain that enables secure, anonymous reporting of corruption cases with immutable record-keeping.

## Features

- **Anonymous Reporting**: Submit whistleblower reports without revealing your identity
- **Secure Evidence Storage**: Store evidence hashes on the blockchain
- **Immutable Case Registry**: All cases are permanently recorded and cannot be altered
- **Review System**: Trusted reviewers can validate or invalidate reports
- **Resolution Tracking**: Track the status and resolution of each case

## Smart Contract Functions

### For Whistleblowers

- `submit-anonymous-report`: Submit a new whistleblower report anonymously
- `add-evidence`: Add additional evidence to an existing case
- `add-comment`: Add a comment to an existing case

### For Administrators

- `add-reviewer`: Add a trusted reviewer to the system
- `remove-reviewer`: Remove a reviewer from the system
- `change-case-status`: Update the status of a case
- `resolve-case`: Mark a case as resolved and assign a reward
- `reject-case`: Mark a case as rejected with explanation
- `transfer-admin`: Transfer admin privileges to another principal

### For Reviewers

- `vote-on-case`: Vote on the validity of a whistleblower report

### Read-Only Functions

- `get-case`: Get details about a specific case
- `get-case-reporter`: Get the commitment hash of a case reporter
- `get-case-count`: Get the total number of cases
- `is-reviewer`: Check if a principal is a reviewer
- `get-reviewer-vote`: Get a reviewer's vote on a case
- `get-case-evidence`: Get evidence for a
