# CloudWeave Roadmap

本 Roadmap 記錄 CloudWeave 各階段的 high-level goal，不提前設計尚未進入階段的 implementation、服務選型或契約細節。

CloudWeave 採用 Progressive Architecture 與 implementation-first 的學習方式：

**IMPLEMENT → VERIFY → BREAK → DEBUG → EXPLAIN → DOCUMENT → FREEZE**

Architecture Decision 採 Just-in-Time 原則，只在真正遇到問題與 trade-off 時進行決策，不提前替未來 Milestone 設計 solution。

CloudWeave 的主要學習重點為：

- Cloud Architecture
- AWS
- GCP
- Multi-Cloud Architecture
- Event-Driven Architecture
- Reliability
- Security
- Observability
- Infrastructure as Code

Application Development 用來提供真實的 Cloud workload，但不是本專案最主要的學習目標。

**Current Milestone：M2 — PostgreSQL + Docker。**

| Milestone | Goal |
|---|---|
| **M0 — Project Foundation** | 鎖定專案方向、Business Scenario、Architecture Principles，以及 Multi-Cloud 責任切分。 |
| **M1 — Order Service Core** | 建立第一個 transactional workload，包含清楚的 Domain boundary、REST API、Order lifecycle 與可測試的 application structure。 |
| **M2 — PostgreSQL + Docker** | 將暫時性的 In-Memory Persistence 替換為 PostgreSQL，並透過 Docker 與 Docker Compose 建立可重現的本機執行環境。 |
| **M3 — AWS Foundation** | 建立並理解承載 transactional workload 所需的 AWS networking 與 security foundation，包括 VPC、Subnet、Routing、Security Group 與基本 IAM boundary。 |
| **M4 — AWS Deployment** | 將 Order workload 與 PostgreSQL persistence model 部署至 AWS，理解 Container、Compute、Networking、Database 與 Availability 在 Cloud Environment 中的關係。 |
| **M5 — Infrastructure as Code** | 將已理解並驗證的 AWS Infrastructure 轉換為可重現的 Infrastructure as Code，學習 Infrastructure lifecycle、dependency、state 與 environment management。 |
| **M6 — CI/CD** | 自動化 Build、Test 與 Deployment，並建立適當的 Cloud authentication，使部署流程不再依賴手動操作。 |
| **M7 — Event-Driven AWS** | 導入 asynchronous Domain Events 與 AWS messaging，讓 transactional workload 與 downstream processing 解耦。 |
| **M8 — Reliable Event Processing** | 實際面對 Event delivery failure，並導入 Retry、DLQ、Idempotency 與可靠的 Transactional Event Publication 等機制。 |
| **M9 — GCP Foundation** | 建立 Cross-Cloud workload 所需的最小 GCP Compute、Messaging、IAM 與相關基礎環境。 |
| **M10 — AWS → GCP Integration** | 將選定的 Business Events 從 AWS 非同步傳遞至 GCP，並建立適當的 Cross-Cloud Trust Boundary。 |
| **M11 — Analytics Processing** | 在 GCP 處理來自 AWS 的 Events，並透過 GCP Serverless / Data Services 留下可分析與回顧的資料。 |
| **M12 — GCP → AWS Return Path** | 將 GCP Processing / Risk Result 非同步送回 AWS，同時維持 Event Identity、Correlation、Retryability 與 Failure Visibility。 |
| **M13 — Distributed Workflow** | 協調 Order、Payment / Risk Result 與 Failure Handling，理解 Eventual Consistency、Compensation 與 Distributed Workflow Coordination。 |
| **M14 — Observability** | 透過 Logs、Metrics、Traces 與 Distributed Context，讓一筆 Transaction 跨 Application、AWS、GCP 與 Messaging Boundary 的路徑可被關聯與解釋。 |
| **M15 — Chaos & Reliability Validation** | 刻意製造 Failure，透過可重現的 Game Day 驗證 Failure Isolation、Retry、Recovery、Observability 與 Reliability Expectations。 |
| **M16 — Portfolio Freeze** | 整理 Architecture Diagram、ADR、Reliability Evidence、Security Decisions、Demo、README 與 Resume-ready Project Narrative，完成作品集。 |

每個 Milestone 仍須經過：

**IMPLEMENT → VERIFY → BREAK → DEBUG → EXPLAIN → DOCUMENT → FREEZE**

Roadmap 可以隨著實際學習與 Architecture Discovery 演化；已 Freeze 的 Domain、Contract 或 Architecture Decision，若未來需要改變，則應先進行 Impact Analysis，而不是無理由重寫。