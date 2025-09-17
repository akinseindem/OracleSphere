OracleSphere
============

A robust and secure smart contract for validating prediction market outcomes on the Stacks blockchain, leveraging a **decentralized oracle network** with a **reputation-based voting system**. OracleSphere is engineered to ensure market integrity, prevent fraud, and align economic incentives through a comprehensive framework that includes dispute resolution, automated payouts, and a dynamic reputation system.

* * * * *

Table of Contents
-----------------

-   Features

-   Core Concepts

-   Contract Architecture

-   Data Structures

-   Functions

-   Economic Incentives & Security

-   Error Codes

-   How to Use

-   Deployment & Verification

-   Contributing

-   License

* * * * *

Features
--------

🔮 **Decentralized Oracle Network**: A permissionless network of validators who stake STX tokens to participate in outcome validation.

🗳️ **Reputation-Based Voting**: Oracles are assigned a reputation score that adjusts dynamically based on their validation accuracy, penalizing malicious actors and rewarding honest ones.

⚖️ **Consensus Mechanism**: Market outcomes are finalized only after reaching a **67% consensus threshold** among validators, ensuring a high degree of confidence and resistance to manipulation.

🛡️ **Comprehensive Fraud Prevention**: The contract includes advanced metrics like `vote-distribution-entropy`, `stake-concentration-ratio`, and `collusion-detection-score` to identify and mitigate fraudulent activity.

🤑 **Economic Incentive Alignment**: Honest oracles are rewarded with a percentage of the market's total volume, while malicious oracles are subject to a **20% stake slashing** penalty.

⏱️ **Time-Bound Validation & Dispute Windows**: Clearly defined timeframes for validation (`VALIDATION-WINDOW`) and dispute resolution (`DISPUTE-WINDOW`) ensure timely market finalization.

💰 **Automated Payouts**: Once an outcome is validated, the contract automatically processes and distributes payouts to winning market participants.

* * * * *

Core Concepts
-------------

-   **Oracles**: Entities (principals) that stake STX to validate prediction market outcomes. They are the backbone of the decentralized validation process.

-   **Prediction Markets**: Represented by a unique `market-id`, these are the core assets of the contract, each with a specific question and resolution source.

-   **Reputation Score**: A numerical value assigned to each oracle, starting at 500. This score increases for correct validations and decreases for incorrect ones, acting as a measure of an oracle's trustworthiness.

-   **Staking**: Oracles must stake a minimum of **1 STX (`u1000000`)** to become eligible to participate in validation. This stake serves as collateral against malicious behavior.

-   **Consensus**: A simple majority (67%) is required for an outcome to be considered final. Votes are counted based on the number of oracles, not their stake, to prevent whale dominance.

-   **Slashing**: A security mechanism where a portion of a validator's staked collateral is removed and burned (or redirected to a penalty pool) if they submit an incorrect or malicious vote.

* * * * *

Contract Architecture
---------------------

The contract is structured into three main sections:

1.  **Constants & Data**: Defines all immutable values (like `MIN-ORACLE-STAKE`) and the core data structures (`maps` and `vars`) that store the state of markets and oracles.

2.  **Private Functions**: Helper functions that perform internal calculations, such as `calculate-oracle-reward` and `update-oracle-reputation`. These functions cannot be called directly from outside the contract.

3.  **Public Functions**: The main entry points for user interaction, including `register-oracle`, `submit-outcome-validation`, and the complex `finalize-market-outcome-and-distribute-rewards`.

The contract's design prioritizes **modularity** and **auditability**, with clear separation between data, internal logic, and public API.

* * * * *

Data Structures
---------------

The contract uses several maps and variables to manage state:

### Variables

-   `next-market-id`: A counter for assigning unique IDs to new prediction markets.

-   `total-staked-amount`: Tracks the total STX staked by all active oracles.

-   `active-oracles-count`: Keeps a tally of the number of currently registered oracles.

### Maps

-   `prediction-markets`: A map that stores all information related to a specific prediction market, indexed by its `market-id`.

-   `oracle-registry`: A map that holds the reputation, stake, and validation history for each registered oracle, indexed by their principal address.

-   `validation-votes`: Stores individual vote details for each oracle on a specific market, using a tuple of `{market-id, oracle}` as the key.

-   `market-validation-summary`: A summary of the voting results for each market, including total votes, vote counts per outcome, and the total staked amount voted.

* * * * *

Functions
---------

### Public Functions

-   `(register-oracle (stake-amount uint))`: Allows a principal to register as an oracle by staking the `MIN-ORACLE-STAKE` or more.

-   `(create-prediction-market (question (string-ascii 256)) (resolution-source (string-ascii 128)) (resolution-deadline uint))`: Deploys a new prediction market, defining its question, resolution source, and the block height by which an outcome should be reached.

-   `(submit-outcome-validation (market-id uint) (outcome-vote uint) (confidence-score uint))`: Enables an oracle to submit their vote for a market's outcome (0 = NO, 1 = YES, 2 = INVALID). The `confidence-score` provides an additional layer of data for future reputation and fraud analysis.

-   `(finalize-market-outcome-and-distribute-rewards (market-id uint) (force-finalization bool) (process-disputes bool) (calculate-reputation-adjustments bool) (distribute-oracle-rewards bool) (execute-market-payouts bool))`: The master function for finalizing a market. It calculates consensus, distributes rewards and penalties, updates reputations, and triggers the final payouts to market participants. The boolean parameters allow for a phased finalization process.

### Private Functions

Private functions are internal to the smart contract and cannot be called directly by external users. They are crucial for orchestrating complex logic and maintaining the integrity of the contract's state.

-   `(get-max (a uint) (b uint))`: A simple utility to return the larger of two unsigned integers.

-   `(get-max-of-three (a uint) (b uint) (c uint))`: Extends the `get-max` logic to three unsigned integers, used to find the most-voted outcome.

-   `(calculate-oracle-reward (market-volume uint) (oracle-stake uint) (total-vote-stake uint))`: This function determines an individual oracle's reward. The reward is a portion of the total reward pool, calculated proportionally to their staked amount relative to the total stake voted by all honest oracles. This formula ensures that oracles with a greater stake in a correct outcome receive a larger share of the rewards.

-   `(update-oracle-reputation (oracle principal) (correct-vote bool))`: A fundamental part of the reputation system. If an oracle's vote aligns with the final consensus, their reputation score increases by `u10`. Conversely, if their vote is incorrect, their score decreases by `u20`, making the penalty for a bad vote twice as impactful as the reward for a good one. This asymmetric design strongly disincentivizes malicious behavior.

-   `(calculate-consensus (market-id uint))`: This function is the core of the validation process. It calculates the percentage of votes for each outcome (Yes, No, Invalid) and determines if any outcome has met or exceeded the `MIN-CONSENSUS-THRESHOLD` of 67%. It returns the winning outcome if consensus is reached, or `none` otherwise.

* * * * *

Economic Incentives & Security
------------------------------

The contract's security is rooted in its economic design:

-   **Slashing (`SLASH-PERCENTAGE` = 20%)**: Oracles who vote against the final consensus are penalized, making it economically irrational to submit a malicious vote without a high degree of confidence in the network's vulnerability.

-   **Rewards (`ORACLE-REWARD-PERCENTAGE` = 5%)**: A portion of the market's total volume is allocated as a reward pool for honest validators. Rewards are distributed proportionally to the stake and correct votes, incentivizing participation and accurate validation.

-   **Reputation System**: A high reputation score not only signifies trustworthiness but could also be used in future versions to give an oracle more influence or exclusive access to high-value markets. The dynamic nature of the reputation score ensures long-term accountability.

-   **Multi-Factor Finalization**: The `finalize-market-outcome-and-distribute-rewards` function is a single, powerful engine that handles all aspects of market conclusion, ensuring atomic and secure state transitions. The inclusion of `integrity-assessment` metrics provides real-time feedback on network health.

* * * * *

Error Codes
-----------

-   `ERR-UNAUTHORIZED`: The transaction sender does not have permission for this action.

-   `ERR-MARKET-NOT-FOUND`: The specified `market-id` does not exist.

-   `ERR-ALREADY-VALIDATED`: The market has already been finalized and cannot be validated again.

-   `ERR-VALIDATION-PERIOD-EXPIRED`: The validation window has closed.

-   `ERR-INSUFFICIENT-STAKE`: The staked amount is less than `MIN-ORACLE-STAKE`.

-   `ERR-INVALID-OUTCOME`: The submitted outcome vote is not 0, 1, or 2.

-   `ERR-ORACLE-NOT-ELIGIBLE`: The transaction sender is not a registered or active oracle.

-   `ERR-DISPUTE-WINDOW-CLOSED`: The dispute resolution period has ended.

* * * * *

How to Use
----------

1.  **Register as an Oracle**: Call `register-oracle` with a sufficient `stake-amount`.

2.  **Create a Market**: A market creator can call `create-prediction-market` to propose a new event for validation.

3.  **Submit a Vote**: Oracles can call `submit-outcome-validation` to cast their vote on a market's outcome.

4.  **Finalize the Market**: Once the `VALIDATION-WINDOW` has passed, the `finalize-market-outcome-and-distribute-rewards` function can be called to process all votes, finalize the outcome, and distribute rewards.

* * * * *

Deployment & Verification
-------------------------

This contract is designed for the Stacks blockchain. It can be deployed and verified using the Stacks CLI or a web-based IDE like the Stacks.js Playground.

Bash

```
# Example deployment command
npx clarity-cli deploy ./oracle-sphere.clar --network mainnet

```

* * * * *

Contributing
------------

Contributions are welcome! Please feel free to open issues or submit pull requests for any bugs, security vulnerabilities, or feature enhancements.

* * * * *

License
-------

Plaintext

```
MIT License

Copyright (c) 2024 OracleSphere

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```
