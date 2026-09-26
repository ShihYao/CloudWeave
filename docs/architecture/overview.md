# CloudWeave Architecture Overview

本文件描述 **目前已確認的高層責任切分**。它不是服務清單，也不選定 AWS / GCP 的具體產品。

Current Milestone 是 M0。圖中「尚未實作」的路徑只表示方向，不表示系統已經跑得通。

## Business Scenario

CloudWeave 假裝服務一家極小的線上店：一次一張 **Order**、一筆 **Payment**，之後再做 **Fraud/Risk Analysis**。

系統要解決的問題是：訂單與付款必須是可信的 system of record（正式帳本）；風險判斷可以晚到，但不能讓分析側直接改帳本，也不能把顧客當下的下單／付款綁死在另一朵雲是否可用。

明確不做完整電商、前台、庫存、物流、真實金流、機器學習風控。細節以 M0 已確認的 business boundary 為準。

## High-level responsibility

```text
客戶面對的交易動作
        │
        ▼
┌───────────────────────────────────────┐
│  AWS — transactional workload         │
│  Order / Payment 帳本                 │
│  唯一能確認或取消訂單的寫入者           │
└───────────────────────────────────────┘
        │
        │  asynchronous event boundary
        │  （業務事實往前送；不是共用資料庫）
        ▼
┌───────────────────────────────────────┐
│  GCP — event processing / analytics   │
│  處理已發生的事實、風險意見、回顧紀錄   │
│  不擁有 Order / Payment 的正式狀態     │
└───────────────────────────────────────┘
        ╎
        ╎  未來可能：return event path
        ╎  （風險意見非同步回到 AWS）
        ╎
        └──────────────────────────────► AWS 依意見改自己的帳本
```

### AWS — transactional workload

負責必須立刻有正式紀錄的工作：建立／查詢訂單、啟動付款（模擬授權／扣住）、以及最終把訂單標成確認或取消。

AWS 是帳本擁有者（Single Writer）。顧客面對的下單與付款路徑，不應同步等待 GCP。

### Asynchronous event boundary

跨雲的業務溝通是非同步的。傳送的是「已經發生的商務事實」，不是把 GCP 當成 AWS 內部的函式呼叫，也不是讓兩邊共用同一本交易資料。

這個 boundary 是為了未來 event-driven integration 保留彈性。傳遞用什麼產品、契約長什麼樣子，現在不決定。

### GCP — event processing / analytics

負責處理已發生的事件、產生 Fraud/Risk 意見，以及留下可供回顧的紀錄。GCP 給的是意見與分析，不是第二份訂單主檔。

### 未來可能加入的 return event path

之後風險意見需要回到 AWS，由交易側決定確認或取消。那是一條 **非同步回程**，不是 GCP 遠端改單。M0 只保留這個方向，不設計回程的驗證、重試或基礎設施。

## Architecture Principles

1. **Cloud Responsibility by Workload** — 依工作性質切分雲，不在兩邊複製同一套商務功能。
2. **Loose Coupling** — 商務語意不綁死傳遞方式；跨雲預設 asynchronous events。
3. **Single Writer for the System of Record** — 只有交易側寫入 Order / Payment 正式狀態。
4. **Failure Isolation** — 分析／風控側失敗，不應讓帳本無法先被正確記下。
5. **Security by Default** — 身分、權限、機密與對外邊界是架構的一部分；與業務規則分開。
6. **Observability by Design** — 設計時就假設必須能解釋一張單走到哪、失敗在哪一側。
7. **Cost-Aware Learning Environment** — 學習環境可拆除、避免 24/7 昂貴資源。
8. **Simple, Testable Design over Hypothetical Scale** — 不為尚未存在的規模或商務域 overlay 複雜度。

## 本文件不涵蓋

- Database schema、API、Event schema
- 具體 AWS / GCP service 選型
- 回程事件的實作設計
