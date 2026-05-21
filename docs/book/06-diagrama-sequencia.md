# 06. Diagrama de Sequencia

[⬅ Voltar ao indice do book](README.md)

## Conversao de visitante para membro de celula

```mermaid
sequenceDiagram
    actor Lider as Lider/Admin (App)
    participant UI as Flutter UI
    participant API as API Express
    participant VC as VisitorController
    participant CMR as CellMemberRepository
    participant VR as VisitorRepository
    participant DB as PostgreSQL

    Lider->>UI: Clica "Transformar em membro"
    UI->>API: PATCH /v1/visitors/{id}/convert-member
    API->>VC: convertToMember(req)
    VC->>CMR: convertVisitorToMember(visitorId, cellId?)
    CMR->>DB: SELECT visitor
    DB-->>CMR: visitor
    CMR->>DB: INSERT cell_members (...)
    CMR->>DB: UPDATE visitors SET status='integrado'
    DB-->>CMR: member criado
    CMR-->>VC: member
    VC->>VR: findById(visitorId)
    VR->>DB: SELECT visitor atualizado
    DB-->>VR: visitor
    VR-->>VC: visitor
    VC-->>API: { member, visitor }
    API-->>UI: 200 OK
    UI-->>Lider: Atualiza tela anterior com novo status
```

## Atualizacao de status por tag no detalhe

```mermaid
sequenceDiagram
    actor Lider as Lider/Admin
    participant UI as VisitorDetailSheet
    participant API as API Express
    participant VC as VisitorController
    participant UVS as UpdateVisitorStatusUseCase
    participant VR as VisitorRepository
    participant DB as PostgreSQL

    Lider->>UI: Toca em uma tag de status
    UI->>API: PATCH /v1/visitors/{id}/status
    API->>VC: updateStatus(req)
    VC->>UVS: execute(id, status)
    UVS->>VR: updateStatus(id, status)
    VR->>DB: UPDATE visitors
    DB-->>VR: visitor atualizado
    VR-->>UVS: visitor
    UVS-->>VC: visitor
    VC-->>API: { visitor }
    API-->>UI: 200 OK
    UI-->>Lider: Fecha detalhe e recarrega listagem
```

[⬅ Voltar ao indice do book](README.md)
