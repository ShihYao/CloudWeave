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

**Current Milestone: M6 — CI/CD**

M5 已完成並 Freeze。M6 正在建立 GitHub Actions CI/CD、GitHub OIDC、immutable image delivery、ECS deployment verification 與 failure evidence。

目前已完成：

- Business Scenario 已定義
- Architecture Principles 已定義
- 第一個 Architecture Decision 已記錄：[為什麼選擇 Multi-Cloud](docs/adr/ADR-001-why-multicloud.md)
- Order Service 的 Domain、REST API 與 lifecycle 已完成
- PostgreSQL、Flyway、Spring Data JPA persistence 已完成
- Order Service 與 PostgreSQL 可透過 Docker Compose 在本機啟動
- M3 AWS Foundation Design 與 M4 Terraform AWS Foundation 已完成並 Freeze
- Terraform 已在 `ap-southeast-2` 部署 ECR、ALB、ECS/Fargate、RDS PostgreSQL、Secrets Manager 整合與 CloudWatch Logs
- ECR `m5-v1`、ECS steady state、ALB target health、private RDS、Flyway migration、Order API state transitions 與 Task replacement persistence 均已驗證

M0 至 M4 已完成並 Freeze。M5 workload 已由 Terraform 建立並完成 baseline 驗證；正式 Freeze 前仍需完成 failure experiment 與 debug evidence。M5 的服務、traffic flow、secret delivery、驗證證據與 destroy 注意事項見 [M5 Terraform AWS Workload Deployment](docs/learning/m5-terraform-aws-workload-deployment.md)。AWS foundation 設計見 [M3 AWS Foundation](docs/learning/m3-aws-foundation.md)，後續 Milestone 見 [roadmap](docs/roadmap.md)，高層責任切分見 [architecture overview](docs/architecture/overview.md)。

## 一句話

把「這張訂單算不算數」留在 AWS 的 transactional workload（交易工作負載）；把「這筆交易安不安全、之後怎麼回顧」放到 GCP 的 event processing / analytics（事件處理與分析）；兩邊用 asynchronous events（非同步事件）整合。

## 為什麼是 Multi-Cloud

全放 AWS 比較簡單、便宜、好維護。CloudWeave 仍選擇 AWS + GCP，不是因為 Multi-Cloud 天生比較好，而是因為跨雲會製造值得學的問題：跨雲信任、非同步整合、失敗處理、資料邊界。完整 rationale 見 ADR-001。

## 學習環境

這是 cost-optimized learning environment，不是 24/7 production。M5 目前使用單一 Fargate Task、Single-AZ RDS，並刻意不建立 NAT Gateway。會持續產生費用的資源，必須在建立前提醒並可拆除。

- ALB、LCU 與 public IPv4
- ECS/Fargate compute 與 Task public IPv4
- RDS instance、storage 與 backup
- Secrets Manager secret
- CloudWatch Logs storage／ingestion
- ECR image storage

沒有 NAT Gateway 費用。短期 learning session 結束後，不應讓 ALB、RDS 與 Fargate 無意義地 24/7 運行；清理前必須先審查 Terraform destroy plan，避免連同已 Freeze 的 M4 foundation 一起移除。
