# Diagram patterns

Four kinds, worked. Copy the nearest and adapt. Each shows the unhappy path,
because that is the part prose omits and the part implementation forgets.

## Lifecycle — `stateDiagram-v2`

Something has states and only some transitions are legal. The edge labels are
the events, and they carry most of the information.

```mermaid
stateDiagram-v2
    [*] --> Pending: record created
    Pending --> Active: payment clears
    Pending --> Failed: payment declined
    Pending --> Expired: 7 days elapsed
    Active --> Cancelled: user cancels
    Active --> Expired: term ends
    Failed --> Pending: user retries
    Cancelled --> [*]
    Expired --> [*]
```

The value here: `Failed → Pending` is a real edge someone will forget, and
`Active → Expired` and `Cancelled → [*]` differ in a way prose blurs.

## Sequence — `sequenceDiagram`

Three or more participants, order matters. Use `alt` for the failure branch —
the whole reason to draw this rather than list steps.

```mermaid
sequenceDiagram
    participant B as Browser
    participant A as API
    participant S as Store
    participant P as Payments

    B->>A: POST /api/v1/orders
    A->>S: BeginTx()
    A->>P: Charge(amount)
    alt charge succeeds
        P-->>A: 200 {id}
        A->>S: Commit()
        A-->>B: 201 {order}
    else charge declined
        P-->>A: 402
        A->>S: Rollback()
        A-->>B: 422 {error, details}
    end
```

Aliases (`participant B as Browser`) keep arrows short. Participant names with
spaces break without them.

## Schema — `erDiagram`

Tables and cardinality. Cardinality is the thing prose gets wrong.

```mermaid
erDiagram
    USERS ||--o{ RECORDS : owns
    RECORDS }o--o{ TAGS : "tagged with"
    RECORDS ||--o{ REVISIONS : "has history"

    USERS {
        uuid id PK
        text email UK
    }
    RECORDS {
        uuid id PK
        uuid owner_id FK
        text name
        timestamptz deleted_at "null = live"
    }
```

Read the crow's feet: `||--o{` is one-to-many, `}o--o{` many-to-many. Include
only the columns the ticket touches — a full schema dump is noise.

## Branching — `flowchart TD`

A decision tree or validation cascade with more than two outcomes.

```mermaid
flowchart TD
    A[PATCH /records/:id] --> B{body parses?}
    B -- no --> E1[400 malformed]
    B -- yes --> C{record exists?}
    C -- no --> E2[404]
    C -- yes --> D{fields valid?}
    D -- no --> E3[422 with details]
    D -- yes --> F[apply non-nil fields]
    F --> G[200 with updated record]
```

Quote any label containing `(`, `)`, `:` or `,`. Never use `end` as a node id —
it is reserved and breaks the render.

## Syntax that silently breaks GitHub

| Breaks | Fix |
|---|---|
| `A[Charge (card)]` | `A["Charge (card)"]` |
| `end` as a node id | rename it `done`, `finish` |
| `participant Order Service` | `participant OS as Order Service` |
| Smart quotes from a doc | plain ASCII quotes |
| A blank line inside the fence | remove it |

GitHub shows a failed diagram as an empty block or raw text with no error.
Always open the issue and look after posting.
