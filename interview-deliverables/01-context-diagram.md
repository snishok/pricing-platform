# 1) Context Diagram

## Objective

Show how the Pricing Platform interacts with users and external systems in the enterprise landscape.

## Context diagram (C4 level 1)

```mermaid
flowchart LR
    U1[Pricing Analyst]
    U2[Store Operations User]
    U3[Data Steward / Category Manager]
    U4[Admin / SRE]

    A1[Store Feed Producers\nCSV files from store systems]
    A2[Identity Provider\nor local auth]
    A3[Monitoring and Alerting\nPrometheus/Grafana/Alertmanager]
    A4[Log and Audit Sink\nSIEM / centralized logs]

    P[Pricing Platform\nSPA + API + Data Services]

    U1 -->|Search, filter, compare prices| P
    U2 -->|Upload daily or intraday CSV feeds| P
    U3 -->|Edit and correct pricing records| P
    U4 -->|Manage users, API keys, operations| P

    A1 -->|CSV feed upload| P
    P -->|Token verification / authn| A2
    P -->|Metrics and health signals| A3
    P -->|Audit events and security logs| A4
```

## System boundary

- Included:
  - Ingestion API for CSV upload
  - Search API and query service
  - Record update API with audit trail
  - SPA for upload/search/edit workflows
- Excluded:
  - Upstream ERP/POS generation logic
  - Downstream repricing engine (can be integrated later)
