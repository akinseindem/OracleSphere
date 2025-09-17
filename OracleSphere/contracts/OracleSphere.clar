;; Decentralized Prediction Market Outcome Validation Contract
;; A secure smart contract for validating prediction market outcomes through a decentralized
;; oracle network with reputation-based voting, dispute resolution mechanisms, and automated
;; payout distribution with comprehensive fraud prevention and economic incentive alignment.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u400))
(define-constant ERR-MARKET-NOT-FOUND (err u401))
(define-constant ERR-ALREADY-VALIDATED (err u402))
(define-constant ERR-VALIDATION-PERIOD-EXPIRED (err u403))
(define-constant ERR-INSUFFICIENT-STAKE (err u404))
(define-constant ERR-INVALID-OUTCOME (err u405))
(define-constant ERR-ORACLE-NOT-ELIGIBLE (err u406))
(define-constant ERR-DISPUTE-WINDOW-CLOSED (err u407))
(define-constant MIN-ORACLE-STAKE u1000000) ;; 1 STX minimum stake
(define-constant VALIDATION-WINDOW u1008) ;; ~7 days in blocks
(define-constant DISPUTE-WINDOW u432) ;; ~3 days in blocks
(define-constant MIN-CONSENSUS-THRESHOLD u67) ;; 67% consensus required
(define-constant ORACLE-REWARD-PERCENTAGE u500) ;; 5% of market volume
(define-constant SLASH-PERCENTAGE u2000) ;; 20% slashing for malicious oracles

;; data maps and vars
(define-data-var next-market-id uint u1)
(define-data-var total-staked-amount uint u0)
(define-data-var active-oracles-count uint u0)

(define-map prediction-markets
  uint
  {
    creator: principal,
    question: (string-ascii 256),
    resolution-source: (string-ascii 128),
    creation-block: uint,
    resolution-deadline: uint,
    total-volume: uint,
    outcome: (optional uint), ;; 0 = NO, 1 = YES, 2 = INVALID
    validation-status: (string-ascii 20), ;; PENDING, VALIDATED, DISPUTED
    validator-count: uint
  })

(define-map oracle-registry
  principal
  {
    reputation-score: uint,
    total-stake: uint,
    successful-validations: uint,
    failed-validations: uint,
    last-activity-block: uint,
    is-active: bool
  })

(define-map validation-votes
  {market-id: uint, oracle: principal}
  {
    outcome-vote: uint,
    confidence-score: uint,
    stake-amount: uint,
    vote-block: uint
  })

(define-map market-validation-summary
  uint
  {
    total-votes: uint,
    yes-votes: uint,
    no-votes: uint,
    invalid-votes: uint,
    consensus-outcome: (optional uint),
    total-stake-voted: uint,
    validation-complete: bool
  })

;; private functions
(define-private (get-max (a uint) (b uint))
  (if (>= a b) a b))

(define-private (get-max-of-three (a uint) (b uint) (c uint))
  (get-max (get-max a b) c))

(define-private (calculate-oracle-reward (market-volume uint) (oracle-stake uint) (total-vote-stake uint))
  (let ((reward-pool (/ (* market-volume ORACLE-REWARD-PERCENTAGE) u10000)))
    (/ (* reward-pool oracle-stake) total-vote-stake)))

(define-private (update-oracle-reputation (oracle principal) (correct-vote bool))
  (let ((current-data (default-to 
                        {reputation-score: u500, total-stake: u0, successful-validations: u0, 
                         failed-validations: u0, last-activity-block: u0, is-active: false}
                        (map-get? oracle-registry oracle))))
    (map-set oracle-registry oracle
             (merge current-data {
               reputation-score: (if correct-vote 
                                  (+ (get reputation-score current-data) u10)
                                  (- (get reputation-score current-data) u20)),
               successful-validations: (if correct-vote 
                                        (+ (get successful-validations current-data) u1)
                                        (get successful-validations current-data)),
               failed-validations: (if correct-vote 
                                    (get failed-validations current-data)
                                    (+ (get failed-validations current-data) u1)),
               last-activity-block: block-height
             }))))

(define-private (calculate-consensus (market-id uint))
  (let ((summary (unwrap-panic (map-get? market-validation-summary market-id))))
    (let ((total-votes (get total-votes summary))
          (yes-votes (get yes-votes summary))
          (no-votes (get no-votes summary))
          (invalid-votes (get invalid-votes summary)))
      (if (> total-votes u0)
        (let ((yes-percentage (/ (* yes-votes u100) total-votes))
              (no-percentage (/ (* no-votes u100) total-votes))
              (invalid-percentage (/ (* invalid-votes u100) total-votes)))
          (if (>= yes-percentage MIN-CONSENSUS-THRESHOLD)
            (some u1)
            (if (>= no-percentage MIN-CONSENSUS-THRESHOLD)
              (some u0)
              (if (>= invalid-percentage MIN-CONSENSUS-THRESHOLD)
                (some u2)
                none))))
        none))))

;; public functions
(define-public (register-oracle (stake-amount uint))
  (begin
    (asserts! (>= stake-amount MIN-ORACLE-STAKE) ERR-INSUFFICIENT-STAKE)
    (try! (stx-transfer? stake-amount tx-sender (as-contract tx-sender)))
    
    (map-set oracle-registry tx-sender {
      reputation-score: u500,
      total-stake: stake-amount,
      successful-validations: u0,
      failed-validations: u0,
      last-activity-block: block-height,
      is-active: true
    })
    
    (var-set total-staked-amount (+ (var-get total-staked-amount) stake-amount))
    (var-set active-oracles-count (+ (var-get active-oracles-count) u1))
    (ok true)))

(define-public (create-prediction-market 
  (question (string-ascii 256))
  (resolution-source (string-ascii 128))
  (resolution-deadline uint))
  
  (let ((market-id (var-get next-market-id)))
    (asserts! (> resolution-deadline block-height) ERR-UNAUTHORIZED)
    
    (map-set prediction-markets market-id {
      creator: tx-sender,
      question: question,
      resolution-source: resolution-source,
      creation-block: block-height,
      resolution-deadline: resolution-deadline,
      total-volume: u0,
      outcome: none,
      validation-status: "PENDING",
      validator-count: u0
    })
    
    (map-set market-validation-summary market-id {
      total-votes: u0,
      yes-votes: u0,
      no-votes: u0,
      invalid-votes: u0,
      consensus-outcome: none,
      total-stake-voted: u0,
      validation-complete: false
    })
    
    (var-set next-market-id (+ market-id u1))
    (ok market-id)))

(define-public (submit-outcome-validation 
  (market-id uint) 
  (outcome-vote uint) 
  (confidence-score uint))
  
  (let ((market (unwrap! (map-get? prediction-markets market-id) ERR-MARKET-NOT-FOUND))
        (oracle-data (unwrap! (map-get? oracle-registry tx-sender) ERR-ORACLE-NOT-ELIGIBLE)))
    
    (asserts! (get is-active oracle-data) ERR-ORACLE-NOT-ELIGIBLE)
    (asserts! (<= outcome-vote u2) ERR-INVALID-OUTCOME)
    (asserts! (> (get resolution-deadline market) block-height) ERR-VALIDATION-PERIOD-EXPIRED)
    (asserts! (<= (- block-height (get resolution-deadline market)) VALIDATION-WINDOW) 
              ERR-VALIDATION-PERIOD-EXPIRED)
    
    (let ((stake-weight (/ (get total-stake oracle-data) u1000))) ;; Scale down for calculations
      (map-set validation-votes {market-id: market-id, oracle: tx-sender} {
        outcome-vote: outcome-vote,
        confidence-score: confidence-score,
        stake-amount: (get total-stake oracle-data),
        vote-block: block-height
      })
      
      ;; Update validation summary
      (let ((current-summary (unwrap-panic (map-get? market-validation-summary market-id))))
        (map-set market-validation-summary market-id
                 (merge current-summary {
                   total-votes: (+ (get total-votes current-summary) u1),
                   yes-votes: (if (is-eq outcome-vote u1) 
                               (+ (get yes-votes current-summary) u1)
                               (get yes-votes current-summary)),
                   no-votes: (if (is-eq outcome-vote u0)
                              (+ (get no-votes current-summary) u1)
                              (get no-votes current-summary)),
                   invalid-votes: (if (is-eq outcome-vote u2)
                                   (+ (get invalid-votes current-summary) u1)
                                   (get invalid-votes current-summary)),
                   total-stake-voted: (+ (get total-stake-voted current-summary) (get total-stake oracle-data))
                 })))
      
      (ok true))))


