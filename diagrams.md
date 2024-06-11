```mermaid
flowchart LR
    stream[(Stream Internal State)]:::green
    bal([Balance - bal]):::green
    rps([RatePerSecond - rps]):::green
    ra([RemainingAmount - ra]):::green
    ltu([Last Time Update - ltu]):::green

    stream --> bal
    stream --> rps
    stream --> ra
    stream --> ltu

    classDef green fill:#32cd32,stroke:#333,stroke-width:2px;
```

```mermaid
flowchart LR
    erc_transfers[(ERC20 Transfer Actions)]:::red
    dep([Deposit - add]):::red
    ref([Refund - extract]):::red
    wtd([Withdraw - extract]):::red

    erc_transfers --> dep
    erc_transfers --> ref
    erc_transfers --> wtd

    classDef red fill:#ff4e4e,stroke:#333,stroke-width:2px;
```

---

### State diagram

**Notes:**

1. The "update" comments refer only to the internal state
2. `ltu` is always updated to `block.timestamp`
3. Blue functions can be called by anyone
4. Purple functions can be called only by the sender

```mermaid
flowchart TD
    %% Functions
    ADJRPS([ADJUST_RPS]):::purple
    CR([CREATE]):::blue
    DP([DEPOSIT]):::blue
    PS([PAUSE]):::purple
    RFD([REFUND]):::purple
    RST([RESTART]):::purple
    WTD([WITHDRAW]):::blue

    %% Statuses
    NULL((NULL)):::grey
    STR((STREAMING)):::green
    PSD((PAUSED)):::yellow

    classDef grey fill:#b0b0b0,stroke:#333,stroke-width:2px;
    classDef green fill:#32cd32,stroke:#333,stroke-width:2px;
    classDef yellow fill:#ffff99,stroke:#333,stroke-width:2px;
    classDef blue fill:#99ccff,stroke:#333,stroke-width:2px;
    classDef purple fill:#D0CEE2,stroke:#333,stroke-width:2px;

    %% ltu is always updated to block.timestamp
    %% the "update" comments refer only to the internal state

    NULL --> CR
    CR -- "update rps\nupdate ltu" --> STR
    ADJRPS -- "update ltu\nupdate ra (+rca)\nupdate rps" -->  STR

    DP -- "update bal (+)" --> STR:::red
    DP -- "update bal (+)" --> PSD:::red

    RFD -- "update bal (-)" --> STR:::red
    RFD -- "update bal (-)" --> PSD:::red

    WTD -- "update ltu\nupdate bal (-)\nupdate ra (-)" --> STR
    WTD -- "update ltu\nupdate bal (-)\nupdate ra (-)" --> PSD

    STR --> PS
    PS -- "update ra (+rca)\nupdate rps (0)" --> PSD
    PSD --> RST
    RST -- "update ltu\nupdate rps" --> STR

    linkStyle 3,4,5,6,7,8 stroke:#ff0000,stroke-width:2px
```

---

### Recent Amount

**Notes:** `now` refers to `block.timestamp`.

```mermaid
flowchart TD
rca([Recent Amount - ra]):::green1
di0{ }:::green0
di1{ }:::green0
res_00([0 ]):::green1
res_01([0 ]):::green1
res_rca(["rps*(now - ltu)"]):::green1

rca --> di0
di0 -- "isNotPaused" --> di1
di0 -- "isPaused" --> res_00
di1 -- "now >= ltu" --> res_01
di1 -- "now < ltu" --> res_rca

classDef green0 fill:#98FB98,stroke:#333,stroke-width:2px;
classDef green1 fill:#32cd32,stroke:#333,stroke-width:2px;
```

### Withdrawable Amount

**Notes:** Debt greater than zero means:

1. `ra > bal`
2. `ra + rca > bal`

```mermaid
flowchart TD
    di0{ }:::blue0
    di1{ }:::blue0
    di2{ }:::blue0
    wa([Withdrawable Amount - wa]):::blue0
    res_0([0 ]):::blue1
    res_bal([bal]):::blue1
    res_ra([ra]):::blue1
    res_sum([rca + ra]):::blue1


    wa --> di0
    di0 -- "bal = 0" --> res_0
    di0 -- "bal > 0" --> di1
    di1 -- "debt > 0" --> res_bal
    di1 -- "debt = 0" --> di2
    di2 -- "isPaused" --> res_ra
    di2 -- "isNotPaused" --> res_sum

    classDef blue0 fill:#DAE8FC,stroke:#333,stroke-width:2px;
    classDef blue1 fill:#1BA1E2,stroke:#333,stroke-width:2px;
    linkStyle 1,2,3,4,5,6 stroke:#1BA1E2,stroke-width:2px
```

### Refundable Amount

```mermaid
    flowchart TD
    rfa([Refundable Amount - rfa]):::orange0
    res_rfa([bal - wa]):::orange1
    rfa --> res_rfa

    classDef orange0 fill:#FFA500,stroke:#333,stroke-width:2px;
    classDef orange1 fill:#FFCD28,stroke:#333,stroke-width:2px;

```

### Stream Debt

```mermaid
flowchart TD
    di0{ }:::red1
    sd([Stream Debt - sd]):::red0
    res_sd(["rca + ra - bal"]):::red1
    res_zero([0]):::red1

    sd --> di0
    di0 -- "bal < rca + ra" --> res_sd
    di0 -- "bal >= rca + ra" --> res_zero

    classDef red0 fill:#EA6B66,stroke:#333,stroke-width:2px;
    classDef red1 fill:#FFCCCC,stroke:#333,stroke-width:2px;

```
