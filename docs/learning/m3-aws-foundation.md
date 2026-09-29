# M3 — AWS Foundation（AWS 基礎建設）

- 狀態：進行中
- 進入日期：2026-09-29
- 範圍：AWS 網路、安全邊界、IAM 憑證衛生、DNS、流量路徑推理、Terraform handoff contract
- 不在本階段範圍：建立 AWS Resource、撰寫 Terraform、ECS、Fargate、RDS、ALB、Order Service 部署

M3 完整設計 AWS 基礎環境，供已 Freeze 的 M1/M2 workload 使用，但不建立任何 AWS Resource。本階段以 Design Freeze 結束，並把可直接實作的 contract 交給 M4；M4 將以 Terraform 作為第一次正式建置方式。本階段不修改 REST API、Domain 規則、PostgreSQL schema、container image 或本機 Docker Compose 工作流程。

## 1. 從 M1/M2 延續的 Freeze 契約

| M1/M2 契約 | 對 M3 的影響 |
|---|---|
| Order API 維持 `/api/v1/orders` | 網路架構不得改變對外 API 契約。 |
| Order Service 監聽 TCP 8080 | 未來 ingress layer 可透過 8080 存取 Application Security Group。 |
| PostgreSQL 監聽 TCP 5432 | 只有 Application Security Group 可透過 5432 存取 Database Security Group。 |
| Application 使用 hostname 連線 | VPC DNS resolution 與 DNS hostnames 必須啟用。 |
| Credential 由環境變數提供 | 不得提交或 hard-code credential；secret delivery 延後至 M4。 |

## 2. 候選網路架構

確認 AWS Account 與部署 Region 前，暫不選定 Region。以下 topology 不依賴特定 Region。

```text
VPC 10.20.0.0/16 (代表前 16 個 bit 固定，因此範圍是：10.20.0.0 到 10.20.255.255)
|
+-- Availability Zone A
|   +-- Public Subnet A   10.20.0.0/24 (代表前 24 個 bit 固定，範圍是：10.20.0.0 到 10.20.0.255)
|   `-- Private Subnet A  10.20.10.0/24 (代表前 24 個 bit 固定，範圍是：10.20.10.0 到 10.20.10.255)
|
`-- Availability Zone B
    +-- Public Subnet B   10.20.1.0/24
    `-- Private Subnet B  10.20.11.0/24
```

VPC 使用 `/16`，為未來增加 subnet tier 與 Availability Zone 保留位址空間。每個 `/24` 遠大於目前 learning workload 的需求，但容易閱讀與檢查。四個 subnet CIDR 彼此不重疊。

Availability Zone 字母是 AWS Account 相對映射。實作時必須從目標 Account 選擇兩個不同的 AZ ID，不可假設其他 Account 的 `a`、`b` 代表相同實體機房。

    識別方式  範例	          特性
(X) AZ Name  ap-northeast-1a	對不同 Account 可能有不同映射
(O) AZ ID	 apne1-az4	      跨 Account 一致地代表同一個實體 AZ

必要的 VPC 設定：

- DNS resolution：啟用 → VPC 裡能不能使用 AWS DNS 解析名稱)
- DNS hostnames：啟用 → AWS 是否替資源提供 DNS hostname)
- Tenancy：Default → EC2 運算資源是否必須使用專屬硬體 (Default tenancy or Dedicated Instance or Dedicated Host)
- 所有支援 tag 的資源包含：`Project=CloudWeave`、`Environment=learning`、`Milestone=M3` 與具辨識力的 `Name`

## 3. 路由模型

Internet Gateway 連接至 VPC。兩個 public subnet 共用一張 public route table：

| Destination | Target |
|---|---|
| `10.20.0.0/16` | local |
| `0.0.0.0/0` | Internet Gateway |

Subnet 之所以是 public，是因為關聯的 route table 有通往 Internet Gateway 的 route。
資源不會只因位於 public subnet 就能被 Internet 存取；它還需要 public IPv4 address（或同等 ingress target）、允許流量的安全控制，以及正在監聽的服務。

兩個 private subnet 使用 private route table，而且絕不直接 route 至 Internet Gateway。

## 4. NAT 決策

| 選項 | 可用性 | 成本 | 跨 AZ 相依性 | 適用情境 |
|---|---|---:|---|---|
| 每個 AZ 一個 NAT Gateway | 最高 | 最高 | 無 | Production 建議方案 |
| 單一 NAT Gateway | 較低 | 中等 | 有 | 折衷環境 |
| 不使用 NAT Gateway | 無一般 outbound IPv4 | 最低 | 無 | M3 learning baseline |

**M3 設計決策：M4 初次建置時不建立 NAT Gateway。** 即使尚未部署 application，NAT Gateway 仍有每小時費用與資料處理費。M3 需要的是 routing 與 security 推理，而非持續提供 private subnet outbound access。這是 portfolio 規模的實作決策，不是 production 建議方案。

M5 部署 task 前必須重新檢視 outbound 需求。拉取 image、傳送 log、取得 secret、patching 或呼叫 AWS API，都需要明確的 egress 設計。比較服務涵蓋範圍與成本後，可選擇每個 AZ 一個 NAT Gateway，以獲得 production 等級 availability；也可建立必要的 VPC Endpoint。只有明確接受 cross-AZ failure dependency 與資料路徑後，才可採用單一 NAT Gateway。

## 5. Security Group 邊界

Security Group 是 stateful。連線獲准後，其 return traffic 自動允許，不需反方向 inbound rule；但 outbound rule 仍決定資源能主動建立哪些新連線。

```text
Internet
   |
   v
Ingress Security Group
   | TCP 8080，source = Ingress SG
   v
Application Security Group
   | TCP 5432，source = Application SG
   v
Database Security Group
```

規劃中的邊界：

- `cloudweave-learning-ingress-sg`：未來 HTTP/HTTPS ingress 邊界。實際 listener port 於 M4 配合 ALB 決定。
- `cloudweave-learning-app-sg`：TCP 8080 inbound 僅允許來自 Ingress SG，不接受直接 Internet source。
- `cloudweave-learning-db-sg`：TCP 5432 inbound 僅允許來自 Application SG，絕不允許 `0.0.0.0/0`。

Security Group reference 可表達 VPC 內的 workload identity，避免 database access 與經常變動的 task IP address 耦合。M3 只定義安全邊界，不建立 Security Group；M4 以 Terraform 建立 foundation rule，需 workload resource 才能完成的 rule 在 M5 由 Terraform 補齊。

## 6. IAM 邊界與憑證衛生

- IAM User 代表人員或舊式長期身份；IAM Role 是可被 assume 的身份；IAM Policy 描述權限。
- 若組織提供 federation/SSO，人員應透過該方式存取 AWS。
- 本機 CLI authentication 必須使用 named profile 或核准的短期 credential flow。
- 不得存在 root-user access key。不得將長期 access key 存於 repository、source code、`.env`、shell history 或文件。
- Consumer 與必要 action 尚未確定前，M3 不建立權限寬鬆的 ECS 或 CI/CD Role。
- 未來每個 workload role 都採 least privilege，並有獨立 trust policy。Permission policy 與 trust policy 分別回答：Role 能做什麼，以及誰能 assume Role。

M4 執行 `terraform plan/apply` 前，先執行 `aws sts get-caller-identity --profile <profile>`，確認為預期的 Account 與 principal。不可將 credential value 放入專案證據或文件。

## 7. DNS 與連線模型

檢查每一條連線時，依以下順序推理：

```text
Application -> DNS Name -> Target Endpoint -> Route / Network Path
            -> Security Group Decision -> Listening Target
```

M2 的 `order-service -> postgres:5432`，概念上轉換為 `future ECS task -> future RDS endpoint:5432`。Hostname 改變並透過 configuration 提供，但 application 與 domain contract 不變。

DNS 查詢成功不代表網路可達。Address 即使解析成功，仍可能因 routing、Security Group、Network ACL 或 target service 而連線失敗。

## 8. 流量路徑預測

| 情境 | 預期結果 | 原因 |
|---|---|---|
| Internet → public-subnet resource | 有條件允許 | 需要 IGW route、public address、SG permission 與 listener。 |
| Private-subnet resource → Internet | M3 baseline 中拒絕 | 沒有經 NAT 或其他 egress service 的 default route。 |
| Internet → private-subnet resource | 拒絕 | 沒有直接 IGW return path/public address；SG 不會建立 route。 |
| Future ECS → future RDS:5432 | 設計上允許 | 使用 private VPC path，且 DB inbound source 為 Application SG。 |
| Internet → future RDS:5432 | 拒絕 | Database 不公開，且 DB rule 不允許 `0.0.0.0/0`。 |

AWS route table 使用 longest-prefix match。
Local `10.20.0.0/16` route 比 `0.0.0.0/0` 更具體(數字越大，代表固定的 bit 越多，涵蓋範圍越小、越精確。)，
因此即使存在 default route，VPC 內部流量仍走 local route。

public subnet 的 route table 如下：
Destination	Target
10.20.0.0/16	local (AWS 自動加入，代表 CloudWeave VPC 內的位址，目的地位於這個 VPC CIDR 時，透過 AWS VPC 內部網路傳送，不同 subnet 中的資源彼此具備網路路徑)
0.0.0.0/0	Internet Gateway (代表所有 IPv4 位址，所以稱為 default route)

情境：連線到 VPC 內部資源
假設 Order Service 的 IP 是： 10.20.10.20 要連線到 PostgreSQL： 10.20.11.30:5432
10.20.0.0/16  → 符合
0.0.0.0/0     → 也符合
連線時會比較 prefix 長度：/16 比 /0 更長、更精確，因此選擇：10.20.0.0/16 → local
將流量留在 VPC 內部

Order Service
10.20.10.20
      |
      | local route
      v
PostgreSQL
10.20.11.30

可以把完整的連線判斷拆成六個關卡：

Client
  |
  | 1. DNS「目的地 IP 是誰？」
  v
Target IP
  |
  | 2. Route Table「封包應該送去哪裡？」
  v
Subnet boundary
  |
  | 3. Network ACL「這個 subnet 邊界允許封包進出嗎？」
  v
Resource / ENI
  |
  | 4. Security Group「這個 resource/ENI 允許此連線嗎？」
  v
Operating System
  |
  | 5. OS Firewall「主機本身允許封包進入嗎？」
  v
Application
  |
  | 6. Listener + Health「服務有監聽，而且能正常處理請求嗎？」
  v
Response

## 9. M3 Design Gate

M3 不建立任何 AWS Resource，也不執行 `terraform apply`。Design Freeze 前必須確認：

- 目標 Region 選擇原則，以及兩個不同 AZ ID 的選擇方法
- VPC 與四個 subnet 的 CIDR、用途、AZ placement 均無歧義
- Public/private route table、Internet Gateway 與 NAT/egress 決策完整
- Security Group 邊界、port、方向與 source SG reference 完整
- DNS、tenancy、tag、IAM 與 credential hygiene 已定義
- M5 workload 所需但尚未建立的 outbound path 已列為明確決策點
- 沒有要求透過 Console 或 AWS CLI 手動預建正式資源

## 10. Terraform Handoff Contract

M4 必須將以下 M3 設計轉換為 Terraform，且 `terraform apply` 是 AWS Resource 的首次建立途徑：

1. 設定 AWS provider、Region 與 default tags；credential 不進入程式碼或 state variable。
2. 建立 `10.20.0.0/16` VPC，啟用 DNS resolution 與 DNS hostnames，使用 default tenancy。
3. 依兩個 AZ 建立四個 `/24` subnet，CIDR 與用途遵循本文件。
4. 建立並連接 Internet Gateway。
5. 建立 public/private route table、route 與明確的 subnet association。
6. Public route table 包含 `0.0.0.0/0 -> IGW`；private route table 不直接指向 IGW。
7. 初次 foundation 不建立 NAT Gateway；若 M5 改變此決策，必須先記錄 cost、availability 與 outbound requirement。
8. 建立 ingress、application、database 三個 Security Group boundary；rule 採 least privilege 與 SG reference。
9. 對支援的資源套用 `Project`、`Environment`、`Milestone` 與 `Name` tags。
10. 建立可重複執行的 `fmt`、`validate`、`plan`、`apply`、verification 與 `destroy` 流程。

M4 必須另外決定並記錄：

- Terraform state backend 與 state 保護方式
- Provider 與 module/version pinning
- Environment variable、local value、output 與 sensitive output 的界線
- Resource dependency 是隱式 reference 還是必要的顯式 dependency
- Teardown owner、時間與成本檢查方式

## 11. Design Verification Checklist

- [ ] CIDR 計算正確，四個 subnet 位於 VPC 內且互不重疊。
- [ ] 兩個不同 AZ 各有一個 public subnet 與一個 private subnet。
- [ ] DNS resolution、DNS hostnames 與 default tenancy 的理由能清楚說明。
- [ ] Public/private 的判斷來自 route，而不是 subnet 名稱。
- [ ] 只有 public route table 設計了 `0.0.0.0/0 -> IGW`。
- [ ] 不建立 NAT 是有意識且具成本理由的初始決策。
- [ ] Database SG 不允許 public CIDR 存取 PostgreSQL。
- [ ] Application-to-database permission 使用 SG reference。
- [ ] 能依 DNS、route、NACL、SG、OS firewall、listener/health 順序診斷連線。
- [ ] Terraform handoff 沒有缺少會迫使實作者自行猜測的關鍵設定。
- [ ] Repository 中沒有 access key 或 secret。

## 12. 延後至 M4 的實際驗證與 Break / Debug

下列工作需要真實 resource，因此不屬於 M3 Design Freeze：

- `terraform fmt`、`validate`、`plan`、`apply` 與實際 AWS resource verification
- 驗證 VPC、subnet、AZ、route、IGW、DNS、SG 與 tags
- 暫時破壞 route、association 或 Security Group rule 的可逆 failure experiment
- 依 DNS → route → NACL → Security Group → target 的順序除錯
- `terraform destroy` 後確認 resource 與持續成本均已移除

實際 break experiment 必須由 Terraform 變更產生並由 Terraform 恢復，不接受事後只在 Console 手動修正，避免 configuration drift。

## 13. Design Freeze Gate

M3 不要求存在任何 AWS Resource。符合以下條件即可 Design Freeze：

- Network、routing、NAT/egress、Security Group、IAM、DNS 與 tag 決策完整
- Traffic flow 與 failure scenario 可以正確解釋
- Terraform handoff contract 可直接實作，沒有未揭露的手動前置資源
- M1/M2 Freeze contract 未被修改
- Roadmap、README 與 architecture overview 已同步

M3 Design Freeze 後進入 M4 — Terraform AWS Foundation。M4/M5 的所有正式 AWS Resource 都以 Terraform 首次建立、修改與銷毀。