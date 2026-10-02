# ADR-001: 為什麼選擇 Multi-Cloud，以及雲的責任切分

- Status: Accepted
- Date: 2026-09-26
- Milestone: M0

## Context

CloudWeave 是 Learning + Portfolio Project。虛構商務流程很小：

- Order 與 Payment 需要可信的 system of record（正式帳本）
- 之後的 Fraud/Risk Analysis 是意見，不是第二本帳
- 交易側根據付款結果與風險意見，把訂單確認或取消

下面兩個方案都能完成這條商務流程。本決策問的不是「哪朵雲比較會做分析」，而是：

**風險與分析要不要放在第二朵雲，並用 asynchronous events（非同步事件）跨過雲的邊界；還是整條鍊留在單一雲裡。**

單雲會比較簡單、便宜、好維護。若仍選 Multi-Cloud，必須是刻意增加 complexity，並用原則把它關在範圍內——不能宣稱這是所有 production system 的最佳方案。

## Options

### Option A — AWS-only

帳本（Order、Payment）與風險／分析都留在 AWS。能力之間仍可用事件鬆開，但整合發生在同一個 control plane（控制平面）、同一套身分與同一套營運表面之內。

### Option B — AWS + GCP Multi-Cloud，依 workload 切分

- AWS 擁有 transactional workload（交易工作負載）：Order、Payment，以及確認或取消訂單的權力。
- GCP 擁有 event processing / analytics（事件處理與分析）：非同步消費已發生的商務事實、產生 Fraud/Risk 意見、留下回顧紀錄。
- GCP 不得寫入 AWS 帳本。AWS 不得把分析儲存當成 system of record。
- 跨雲業務溝通是非同步的。顧客面對的建立訂單／啟動付款，不得同步等待 GCP。

## Decision

選擇 **Option B**。

CloudWeave 使用 AWS + GCP，並依上述 workload 切分責任。

## Rationale

全放 AWS 比較簡單、便宜、好維護——但你學到的主要是「一朵雲怎麼用」。

拆成 AWS + GCP 會增加複雜度——但這些複雜度正好就是 CloudWeave 想學的東西：跨雲信任、非同步整合、失敗處理、資料邊界。

CloudWeave 選 Multi-Cloud 不是因為「Multi-Cloud 比較好」，而是因為它會製造出值得學的問題。

以下理由 **明確拒絕**，後續 ADR 與說明都不要用：

- Multi-Cloud 天生比 Single-Cloud 更可靠
- 兩朵雲可以避免 vendor lock-in（只是改變鎖定形狀，不是解脫）
- 這家虛構小店的商務需求「必須」兩家供應商
- 為了高可用而在兩朵雲部署同一套系統

## Consequences

### 接受的代價

- 架構、營運、安全與成本複雜度都高於 Option A。
- 多一個失敗域：GCP 變慢、中斷、或跨雲路徑失敗時，不得污染帳本。若 Failure Isolation 沒做好，Option B 會比 Option A **更不穩**。
- 兩套供應商表面、兩次拆除，以及個人學習環境的閒置成本風險。

### 本決策加上的限制

- 新能力先分類：帳本，還是 processing / analytics。不為了對稱而在兩邊複製同一套商務功能。
- 交易請求路徑與 GCP 是否可用保持隔離。
- 只有 AWS 寫入 Order / Payment 的正式狀態。Fraud/Risk 結果是輸入，不是「GCP 上的訂單狀態」。
- Cost-Aware Learning Environment 是硬約束：不得因為「架構是 Multi-Cloud」就讓昂貴資源 24/7 開著。
- 後續決策不得用「既然已經 Multi-Cloud」再疊第三朵雲、更多產品，或假想中的大規模。

### 本 ADR 不決定

具體 AWS / GCP service、API、database schema、event schema 都不在本決策範圍。
