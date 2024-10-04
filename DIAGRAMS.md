> [!NOTE]
>
> Below sections assume you've gone through the
> [abbreviations table](https://github.com/sablier-labs/flow/?tab=readme-ov-file#abbreviations) and
> [core components](https://github.com/sablier-labs/flow/?tab=readme-ov-file#core-components)

## Statuses

### Types

| Type      | Statuses                                       | Description           |
| :-------- | :--------------------------------------------- | :-------------------- |
| Streaming | `STREAMING_SOLVENT`, `STREAMING_INSOLVENT`     | Debt is accruing.     |
| Paused    | `PAUSED_SOLVENT`, `PAUSED_INSOLVENT`, `VOIDED` | Debt is not accruing. |

| Status                | Description                                                             |
| --------------------- | ----------------------------------------------------------------------- |
| `STREAMING_SOLVENT`   | Streaming stream when there is no uncovered debt.                       |
| `STREAMING_INSOLVENT` | Streaming stream when there is uncovered debt.                          |
| `PAUSED_SOLVENT`      | Paused stream when there is no uncovered debt.                          |
| `PAUSED_INSOLVENT`    | Paused stream when there is uncovered debt.                             |
| `VOIDED`              | Paused stream with forfeited uncovered debt and it cannot be restarted. |

### Statuses diagram

The transition between statuses is done by specific functions, which can be seen in the text on the edges or by the
time.

```mermaid
stateDiagram-v2
    direction LR

    state Streaming {
        STREAMING_SOLVENT
        STREAMING_INSOLVENT --> STREAMING_SOLVENT : deposit
        STREAMING_SOLVENT --> STREAMING_INSOLVENT : time
    }

    state Paused {
        # direction BT
        PAUSED_SOLVENT
        PAUSED_INSOLVENT
        PAUSED_INSOLVENT --> PAUSED_SOLVENT : deposit
        PAUSED_INSOLVENT --> VOIDED : void
        VOIDED
    }

    STREAMING_SOLVENT --> PAUSED_SOLVENT : pause
    STREAMING_INSOLVENT --> PAUSED_INSOLVENT : pause
    PAUSED_SOLVENT --> STREAMING_SOLVENT : restart
    STREAMING_INSOLVENT --> VOIDED : void
    PAUSED_INSOLVENT --> STREAMING_INSOLVENT : restart

    NULL --> STREAMING_SOLVENT : create (rps > 0)
    NULL --> PAUSED_SOLVENT : create (rps = 0)

    NULL:::grey
    Streaming:::lightGreen
    Paused:::lightYellow
    STREAMING_SOLVENT:::intenseGreen
    STREAMING_INSOLVENT:::intenseGreen
    PAUSED_INSOLVENT:::intenseYellow
    PAUSED_SOLVENT:::intenseYellow
    VOIDED:::intenseYellow

    classDef grey fill:#b0b0b0,stroke:#333,stroke-width:2px,color:#000,font-weight:bold;
    classDef lightGreen fill:#98FB98,color:#000,font-weight:bold;
    classDef intenseGreen fill:#32cd32,stroke:#333,stroke-width:2px,color:#000,font-weight:bold;
    classDef lightYellow fill:#ffff99,color:#000,font-weight:bold;
    classDef intenseYellow fill:#ffd700,color:#000,font-weight:bold;
```

### Function calls

**Notes:**

1. The arrows point to the status on which the function can be called.
2. The "update" comments refer only to the stream internal state.
3. `st` is always updated to `block.timestamp`.
4. Red lines refers to the function that are doing an `ERC-20` transfer

```mermaid
flowchart LR
    subgraph Statuses
        NULL((NULL)):::grey
        STR((STREAMING)):::green
        PSED((PAUSED)):::yellow
        VOID((VOIDED)):::red
    end

    subgraph Functions
        CR([CREATE])
        ADJRPS([ADJUST_RPS])
        DP([DEPOSIT])
        RFD([REFUND])
        PS([PAUSE])
        RST([RESTART])
        VD([VOID])
        WTD([WITHDRAW])
    end

    BOTH((  )):::black


    classDef black fill:#000000,stroke:#333,stroke-width:2px;
    classDef green fill:#32cd32,stroke:#333,stroke-width:2px;
    classDef grey fill:#b0b0b0,stroke:#333,stroke-width:2px;
    classDef yellow fill:#ffff99,stroke:#333,stroke-width:2px;
    classDef red fill:#ff4e4e,stroke:#333,stroke-width:2px;

    CR -- "update rps<br/>update st" --> NULL

    ADJRPS -- "update sd (+od)<br/>update rps<br/>update st" -->  STR

    DP -- "update bal (+)" --> BOTH

    RFD -- "update bal (-)" --> BOTH

    PS -- "update sd (+od)<br/>update rps (0)<br/>update st" --> STR

    BOTH --> STR & PSED

    RST -- "update rps<br/>update st" --> PSED

    VD -- "update sd (bal)<br/>update rps (0)<br/>update st" --> BOTH

    WTD -- "update sd (-)<br/>update st<br/>update bal (-)" --> BOTH
    WTD -- "update sd (-)" --> VOID

    linkStyle 2,3,9,10 stroke:#ff0000,stroke-width:2px
```

## Access Control

| Action              |         Sender         | Recipient | Operator(s) |      Unknown User      |
| ------------------- | :--------------------: | :-------: | :---------: | :--------------------: |
| AdjustRatePerSecond |           ✅           |    ❌     |     ❌      |           ❌           |
| Deposit             |           ✅           |    ✅     |     ✅      |           ✅           |
| Pause               |           ✅           |    ❌     |     ❌      |           ❌           |
| Refund              |           ✅           |    ❌     |     ❌      |           ❌           |
| Restart             |           ✅           |    ❌     |     ❌      |           ❌           |
| Transfer NFT        |           ❌           |    ✅     |     ✅      |           ❌           |
| Void                |           ✅           |    ✅     |     ✅      |           ❌           |
| Withdraw            | ✅ (only to Recipient) |    ✅     |     ✅      | ✅ (only to Recipient) |

### Internal State

The [stream struct](https://github.com/sablier-labs/flow/?tab=readme-ov-file#motivation) has more fields than the ones
shown here, but these are the most relevant ones.

```mermaid
flowchart LR
    stream[(Stream Internal State)]:::green
    bal([Balance - bal]):::green
    rps([RatePerSecond - rps]):::green
    sd([SnapshotDebt - sd]):::green
    st([Snapshot Time - st]):::green

    stream --> bal
    stream --> rps
    stream --> sd
    stream --> st

    classDef green fill:#32cd32,stroke:#333,stroke-width:2px;
```

### ERC-20 Transfer Actions

```mermaid
flowchart LR
    erc_transfers[(ERC20 Transfer Actions)]:::red
    dep([Deposit - add]):::red
    ref([Refund - remove]):::red
    wtd([Withdraw - remove]):::red

    erc_transfers --> dep
    erc_transfers --> ref
    erc_transfers --> wtd

    classDef red fill:#ff4e4e,stroke:#333,stroke-width:2px;
```

$~$

## Amount Calculations

### Ongoing Debt

```mermaid
flowchart TD
rca([Ongoing Debt - od]):::green1
di0{ }:::green0
di1{ }:::green0
res_00([0 ]):::green1
res_01([0 ]):::green1
res_rca(["rps * elt"]):::green1

rca --> di0
di0 -- "rps > 0" --> di1
di0 -- "rps == 0" --> res_00
di1 -- "now <= st" --> res_01
di1 -- "now > st" --> res_rca

classDef green0 fill:#98FB98,stroke:#333,stroke-width:2px;
classDef green1 fill:#32cd32,stroke:#333,stroke-width:2px;
```

### Uncovered Debt

**Notes:** A non-zero uncovered debt implies:

1. `bal < sd` when the status is `PAUSED`
2. `bal < sd + od` when the status is `STREAMING`

```mermaid
flowchart TD
    di0{ }:::red1
    sd([Uncovered Debt - ud]):::red0
    res_sd(["td- bal"]):::red1
    res_zero([0]):::red1

    sd --> di0
    di0 -- "bal < td" --> res_sd
    di0 -- "bal >= td" --> res_zero

    classDef red0 fill:#EA6B66,stroke:#333,stroke-width:2px;
    classDef red1 fill:#FFCCCC,stroke:#333,stroke-width:2px;
```

### Covered debt

```mermaid
flowchart TD
    di0{ }:::blue0
    di1{ }:::blue0
    di2{ }:::blue0
    cd([Covered Debt - cd]):::blue0
    res_0([0 ]):::blue1
    res_bal([bal]):::blue1
    res_sd([sd]):::blue1
    res_sum([td]):::blue1


    cd --> di0
    di0 -- "bal = 0" --> res_0
    di0 -- "bal > 0" --> di1
    di1 -- "ud > 0" --> res_bal
    di1 -- "ud = 0" --> di2
    di2 -- "paused" --> res_sd
    di2 -- "streaming" --> res_sum

    classDef blue0 fill:#DAE8FC,stroke:#333,stroke-width:2px;
    classDef blue1 fill:#1BA1E2,stroke:#333,stroke-width:2px;
    linkStyle 1,2,3,4,5,6 stroke:#1BA1E2,stroke-width:2px
```

### Refundable Amount

```mermaid
    flowchart TD
    ra([Refundable Amount - ra]):::orange0
    res_ra([bal - cd]):::orange1
    ra --> res_ra

    classDef orange0 fill:#FFA500,stroke:#333,stroke-width:2px;
    classDef orange1 fill:#FFCD28,stroke:#333,stroke-width:2px;

```