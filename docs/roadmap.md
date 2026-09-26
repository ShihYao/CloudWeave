# CloudWeave Roadmap

Milestone 數量與順序固定為 **M0–M16**。本文件只記錄每個階段的 high-level goal，不設計該階段的 implementation、服務選型或契約細節。

**Current Milestone：M0。** 未完成的項目不代表已經存在。

| Milestone | Goal |
|---|---|
| **M0 — Project Foundation** | 鎖定專案方向、Business Scenario、Architecture Principles，以及 Multi-Cloud 責任切分。 |
| **M1 — Order Service Core** | 讓交易側能建立與查詢 Order，並為訂單狀態打下可測試的基礎。 |
| **M2 — Local Development Environment** | 讓後續服務能在本機可重現地啟動與驗證，仍不依賴常駐雲端資源。 |
| **M3 — Payment Service Core** | 讓交易側能啟動模擬 Payment，且 Payment 與 Order 的資料擁有權分開。 |
| **M4 — AWS Infrastructure Foundation** | 用 Infrastructure as Code 建立 AWS 學習環境，並能乾淨建立與拆除。 |
| **M5 — CI/CD Foundations** | 讓變更能被自動檢查、建置與有控制地部署，而不是手動把環境堆上去。 |
| **M6 — AWS Event-Driven Backbone** | 讓 AWS 內部能把已發生的商務事實可靠地變成事件，並處理重試與重複投遞。 |
| **M7 — AWS-to-GCP Bridge** | 把選定的商務事實非同步送到 GCP，跨過雲的信任邊界。 |
| **M8 — GCP Event Processing and Analytics** | 讓 GCP 能接收事件、做處理，並留下可供回顧的分析紀錄。 |
| **M9 — Return Event Path** | 讓 GCP 的處理結果能非同步回到 AWS，仍由交易側寫入帳本。 |
| **M10 — Fraud / Risk Analysis** | 用可說明的規則產生風險意見，供交易側決定確認或取消。 |
| **M11 — Reliability Engineering** | 為逾時、過載與失敗定義可觀察的可靠度行為，並分清學習環境與參考環境的差異。 |
| **M12 — Cross-Step Coordination** | 把付款結果與風險意見協調成一張訂單的確認或補償／取消，且過程可重入、可解釋。 |
| **M13 — Security Hardening** | 收緊身分、權限、機密與對外邊界，讓 Security by Default 落到可檢查的控制。 |
| **M14 — Observability** | 讓一筆訂單跨 AWS 與 GCP 的路徑可被關聯與解釋。 |
| **M15 — Chaos and Game Days** | 刻意製造失敗，驗證隔離、恢復與紀錄是否真的有效。 |
| **M16 — Portfolio Freeze** | 對齊原則與 ADR、整理可講解的證據，並寫下已知限制；不再擴充商務範圍。 |

每個 Milestone 仍須經過：BUILD → VERIFY → BREAK → DEBUG → EXPLAIN → DOCUMENT → FREEZE。
