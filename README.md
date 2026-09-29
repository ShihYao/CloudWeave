# CloudWeave

CloudWeave 是個人 **Learning + Portfolio Project**。目標不是做完整電商產品，而是透過一個極小的 Commerce 情境，實際練習：

- Cloud Architecture
- Multi-Cloud
- Distributed Systems
- Event-Driven Architecture（事件驅動架構）
- Reliability
- Security
- Observability
- Infrastructure as Code
- CI/CD

商務範圍只有：**Order**、**Payment**，以及未來的 **Fraud/Risk Analysis**。沒有前台、庫存、物流或真實金流。

## 目前狀態

**Current Milestone：M2 — PostgreSQL + Docker。**

目前已完成：

- Business Scenario 已定義
- Architecture Principles 已定義
- 第一個 Architecture Decision 已記錄：[為什麼選擇 Multi-Cloud](docs/adr/ADR-001-why-multicloud.md)
- Order Service 的 Domain、REST API 與 lifecycle 已完成
- PostgreSQL、Flyway、Spring Data JPA persistence 已完成
- Order Service 與 PostgreSQL 可透過 Docker Compose 在本機啟動

尚未實作 AWS、GCP、Terraform 或任何 Cloud Resource。M2 操作與學習紀錄見 [M2 walkthrough](docs/learning/m2-postgresql-docker.md)，後續 Milestone 見 [roadmap](docs/roadmap.md)，高層責任切分見 [architecture overview](docs/architecture/overview.md)。

## 一句話

把「這張訂單算不算數」留在 AWS 的 transactional workload（交易工作負載）；把「這筆交易安不安全、之後怎麼回顧」放到 GCP 的 event processing / analytics（事件處理與分析）；兩邊用 asynchronous events（非同步事件）整合。

## 為什麼是 Multi-Cloud

全放 AWS 比較簡單、便宜、好維護。CloudWeave 仍選擇 AWS + GCP，不是因為 Multi-Cloud 天生比較好，而是因為跨雲會製造值得學的問題：跨雲信任、非同步整合、失敗處理、資料邊界。完整 rationale 見 ADR-001。

## 學習環境

這是 cost-optimized learning environment，不是 24/7 production。會持續產生費用的資源，必須在建立前提醒並可拆除。
