# M0 Acceptance Checklist

**Current Milestone：M0。本文件不啟動 M1。**

---

### 1. CloudWeave 解決什麼問題？

**問題：** 說明 CloudWeave 要解決的問題。含商務情境，但不要講成完整電商。

**精簡正確答案：**

這不是完整電商產品，而是極小 Commerce 載具：一張 **Order**、一筆 **Payment**，之後再有 **Fraud/Risk** 意見。

商務上要同時成立三件事：

- 訂單與付款是可信的 system of record（正式帳本）
- 風險判斷可以晚到，分析側不能直接改帳本
- 顧客當下的下單／付款，不能同步綁死在另一朵雲是否可用

AWS 擁有訂單／付款與「這張單算不算數」的決策權。GCP 非同步給分析與風險意見。GCP 不直接改單；AWS **可以採用** 意見來確認或取消。專案真正要練的，是切分核心運作域之後浮現的跨雲邊界，不是把商場做大。

---

### 2. 為什麼選 Multi-Cloud？

**問題：** 為什麼選擇 Multi-Cloud，而不是把它講成「兩朵雲比較高級、比較穩」？

**精簡正確答案：**

不是因為比較穩、比較潮，也不是這家虛構小店商務上非跨雲不可。

全放 AWS 比較簡單。拆成 AWS + GCP 會增加複雜度；這些複雜度正好是 CloudWeave 要學的：跨雲信任、asynchronous events、失敗處理、資料邊界。

選 Multi-Cloud 是因為它會製造值得學的問題，不是因為 Multi-Cloud 天生比較好。

---

### 3. 為什麼不是 AWS-only？

**問題：** 有人說 AWS-only 一樣能下單、付款、做風險判斷。AWS-only 少了什麼？CloudWeave 因此放棄了什麼？

**精簡正確答案：**

AWS-only **做得到**同一條商務功能。同一朵雲裡仍可用事件維持 Loose Coupling 與 Single Writer，不必變成分析直接碰帳本。

少掉的是：**跨出另一個 control plane（控制平面）、另一套身分、另一套營運表面** 的邊界。單雲整合比較像同一個控制範圍內的鄰居。

因此放棄的是較低的架構、營運、安全與成本複雜度，以及少一個失敗域。這是刻意付學費，不是產品上的更佳解。

---

### 4. AWS 與 GCP 的 responsibility boundary 是什麼？

**問題：** 各負責什麼、誰能改訂單狀態、跨雲怎麼說話、顧客下單當下能不能同步等 GCP？

**精簡正確答案：**

- AWS：transactional workload。Order、Payment，以及確認或取消的權力。唯一能寫帳本的一方。
- GCP：event processing / analytics。非同步消費已發生的商務事實、產生 Fraud/Risk 意見、留下回顧紀錄。不擁有訂單正式狀態。
- GCP 不得寫入 AWS 帳本。AWS 不得把分析儲存當成 system of record。
- 跨雲業務溝通是非同步的。建立訂單／啟動付款 **不得** 同步等待 GCP。

---

### 5. Multi-Cloud 帶來哪些額外 complexity？

**問題：** 相對於 AWS-only，至少講到架構、營運、安全、成本、失敗模式。

**精簡正確答案：**

- **架構：** 兩個擁有者、兩套設定與部署、一份跨雲契約；移動中的零件變多。
- **營運：** 兩套權限與環境生命週期；除錯要先問斷在哪一側；拆除也是兩家。
- **安全：** 多一條雲對雲信任邊界（誰能送事件、誰能送回意見）；不能假設都在內網。
- **成本：** 閒置與底層固定成本變兩份；學習環境忘了關，漏的是兩家資源。
- **失敗模式：** 多的不是高可用，而是 GCP 或跨雲路徑掛掉這一種新故障。Failure Isolation 沒做好，會比單雲更不穩。

操作負擔是學習內容，不是營運優化。

---

### 6. 為什麼現在不決定具體 cross-cloud transport？

**問題：** 為什麼 M0 不決定事件實際用哪個產品送到另一邊？現在先鎖定的是什麼？

**精簡正確答案：**

M0 鎖定的是 **asynchronous event boundary**：傳「已經發生的商務事實」，不是把 GCP 當 AWS 內部函式呼叫，也不是共用交易資料。

傳遞用什麼產品、契約長什麼樣子，現在不決定。這是為未來 event-driven integration 留彈性，也避免過早綁死實作。

現在就選某個 queue／某個雲產品來傳事件，會破壞 **Loose Coupling**：商務語意不應綁死在某一家 transport。

---

### 7. Architecture Principles 如何避免未來 Milestone 推翻前面的設計？

**問題：** 若有人提議「下單時同步呼叫 GCP 做風控」或「讓 GCP 直接改訂單狀態」，會撞上哪些原則？

**精簡正確答案：**

原則是後續 Milestone 的尺子。要動這些線，是改 Architecture Decision，不是順便實作。

| 提議 | 主要撞上的原則 |
|---|---|
| 下單時同步呼叫 GCP 做風控 | **Failure Isolation**（分析側一掛，下單路徑被拖死）、**Loose Coupling**（交易路徑直接認識並等待分析側）、也擦到 **Cloud Responsibility by Workload** |
| GCP 直接改訂單狀態 | **Single Writer for the System of Record**（分析側寫了帳本）、**Cloud Responsibility by Workload**（GCP 變成交易擁有者） |

其他原則同樣用來擋偏掉：Security by Default、Observability by Design、Cost-Aware Learning Environment、Simple, Testable Design over Hypothetical Scale。

