## Statuses

### Types

| Type   | Statuses                              | Description                                                   |
| :----- | :------------------------------------ | :------------------------------------------------------------ |
| Active | Streaming Insolvent, StreamingSolvent | The amount owed to the recipient is increasing over time.     |
| Paused | PauseSolvent, PausedInsolvent         | The amount owed to the recipient is not increasing over time. |

| Status              | Description                          |
| ------------------- | ------------------------------------ |
| Streaming Solvent   | Active stream when there is no debt. |
| Streaming Insolvent | Active stream when there is debt.    |
| Paused Solvent      | Paused stream when there is debt.    |
| Paused Insolvent    | Paused stream when there is no debt. |

### Statuses diagram

The transition between statuses is done by specific functions, which can be seen in the text on the edges or by the
time.

```mermaid
stateDiagram-v2
    direction LR

    state Active {
        StreamingSolvent
        StreamingInsolvent --> StreamingSolvent : deposit
        StreamingSolvent --> StreamingInsolvent : time
    }

    state Inactive {
        # direction BT
        PauseSolvent
        PausedInsolvent
         PausedInsolvent --> PauseSolvent : deposit || void
    }

    StreamingSolvent --> PauseSolvent : pause
    StreamingInsolvent --> PausedInsolvent : pause
    StreamingInsolvent --> PauseSolvent : void
    PauseSolvent --> StreamingSolvent : restart
    PausedInsolvent --> StreamingInsolvent : restart

    NULL --> StreamingSolvent : create

    NULL:::grey
    Active:::lightGreen
    Inactive:::lightYellow
    StreamingSolvent:::intenseGreen
    StreamingInsolvent:::intenseGreen
    PausedInsolvent:::intenseYellow
    PauseSolvent:::intenseYellow

    classDef grey fill:#b0b0b0,stroke:#333,stroke-width:2px,color:#000,font-weight:bold;
    classDef lightGreen fill:#98FB98,color:#000,font-weight:bold;
    classDef intenseGreen fill:#32cd32,stroke:#333,stroke-width:2px,color:#000,font-weight:bold;
    classDef lightYellow fill:#ffff99,color:#000,font-weight:bold;
    classDef intenseYellow fill:#ffd700,color:#000,font-weight:bold;

```

### Function calls

**Notes:**

1. The "update" comments refer only to the internal state
2. `ltu` is always updated to `block.timestamp`
3. Red lines refers to the function that are doing an ERC20 transfer

```mermaid
flowchart LR
    subgraph Statuses
        NULL((NULL)):::grey
        ACV((ACTIVE)):::green
        INACV((INACTIVE)):::yellow
    end


    subgraph Functions
        CR([CREATE])
        ADJRPS([ADJUST_RPS])
        DP([DEPOSIT])
        WTD([WITHDRAW])
        RFD([REFUND])
        RST([RESTART])
        PS([PAUSE])
        VD([VOID])
    end

    BOTH((  )):::black

    classDef grey fill:#b0b0b0,stroke:#333,stroke-width:2px;
    classDef green fill:#32cd32,stroke:#333,stroke-width:2px;
    classDef yellow fill:#ffff99,stroke:#333,stroke-width:2px;
    classDef black fill:#000000,stroke:#333,stroke-width:2px;

    CR -- "update rps\nupdate ltu" --> NULL
    ADJRPS -- "update ra (+rca)\nupdate rps\nupdate ltu" -->  ACV

    DP -- "update bal (+)" --> BOTH

    RFD -- "update bal (-)" --> BOTH

    VD -- "update ra (bal)\nupdate rps (0)" --> BOTH

    WTD -- "update ra (-) \nupdate ltu\nupdate bal (-)" --> BOTH

    PS -- "update ra (+rca)\nupdate rps (0)" --> ACV

    BOTH --> ACV & INACV

    RST -- "update rps \nupdate ltu" --> INACV

    linkStyle 2,3,5 stroke:#ff0000,stroke-width:2px
```

## Access Control

| Action              |         Sender         | Recipient | Operator(s) |      Unknown User      |
| ------------------- | :--------------------: | :-------: | :---------: | :--------------------: |
| AdjustRatePerSecond |           ✅           |    ❌     |     ❌      |           ❌           |
| Deposit             |           ✅           |    ✅     |     ✅      |           ✅           |
| Refund              |           ✅           |    ❌     |     ❌      |           ❌           |
| Restart             |           ✅           |    ❌     |     ❌      |           ❌           |
| Pause               |           ✅           |    ❌     |     ❌      |           ❌           |
| Transfer NFT        |           ❌           |    ✅     |     ✅      |           ❌           |
| Void                |           ❌           |    ✅     |     ✅      |           ❌           |
| Withdraw            | ✅ (only to Recipient) |    ✅     |     ✅      | ✅ (only to Recipient) |

### Internal State

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

## Amount Calculations

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
di0 -- "active" --> di1
di0 -- "inactive" --> res_00
di1 -- "now < ltu" --> res_01
di1 -- "now >= ltu" --> res_rca

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
    di2 -- "inactive" --> res_ra
    di2 -- "active" --> res_sum

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
