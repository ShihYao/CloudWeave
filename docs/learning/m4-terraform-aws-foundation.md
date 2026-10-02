# M4 — Terraform AWS 基礎建設

- 狀態：已完成並進入 Design Freeze（2026-10-02）
- 唯一真相來源：M3 AWS Foundation Design Freeze
- 範圍：Terraform 設定、本機驗證，以及 plan／apply／verify／drift／destroy／rebuild 學習循環

## 已實作的基礎建設

Terraform root module 位於 infrastructure/terraform/aws，並實作以下項目：

- VPC 10.20.0.0/16，啟用 DNS 支援、DNS hostname，並使用 default tenancy
- 兩個 public subnet（10.20.0.0/24 與 10.20.1.0/24）
- 兩個 private subnet（10.20.10.0/24 與 10.20.11.0/24）
- 兩個由使用者選定且穩定的 Availability Zone ID
- 一個 Internet Gateway，以及一條 public 0.0.0.0/0 route
- 一張 public route table 與兩張 private route table，並具有明確的 subnet association
- Private subnet 沒有預設 Internet route，也沒有 NAT Gateway
- Ingress、application 與 database 三層 Security Group 邊界
- 僅允許從 ingress SG 到 application SG 的 TCP 8080
- 僅允許從 application SG 到 database SG 的 TCP 5432
- Project、Environment、Milestone、ManagedBy、Name 與 Tier tags

## 刻意保留的邊界

Region 與實際的 AZ ID 維持為明確輸入，因為 M3 並未凍結特定 AWS 帳號所對應的一組固定值。執行 plan 前，必須先確認範例值適用於目標 AWS 帳號。

目前沒有建立允許 public HTTP/HTTPS 流量進入的 ingress rule，因為 M3 已將 Load Balancer listener 延後至 M5。此階段也不建立 ECS、RDS、ALB、Elastic IP 或 NAT 資源。

M3 已凍結 credential hygiene 原則，但尚未凍結 IAM trust policy 與 permission policy。ECS roles 屬於 M5，CI/CD federation 屬於 M6；現在預先建立權限寬泛的推測性角色將違反 least privilege 原則。

## State 與身分驗證

M4 使用 local state 作為學習環境的基準。State、variable files 與已儲存的 plan files 均已加入 Git ignore。共享環境或 production environment 在提供團隊使用前，必須採用具備 locking 機制的 remote backend。

身分驗證使用標準 AWS credential chain，也可以選擇使用 named profile。Credential 絕不會作為 Terraform variable，也不得提交至版本控制。

## 驗證證據

截至 2026-10-02：

- Terraform CLI 1.16.4，AWS provider 6.66.0
- AWS CLI profile `cloudweave-dev`，Project `665116832947`，selected Region `ap-southeast-2`
- Availability Zone IDs：`apse2-az1`、`apse2-az3`
- `terraform fmt -check -recursive`、`terraform validate` 均通過
- Mock provider contract test：`1 passed, 0 failed`
- Initial plan/apply：`21 added, 0 changed, 0 destroyed`
- AWS actual resource 驗證通過：VPC、DNS、4 subnets、IGW、routes、associations、3 個 managed security groups 與 tags 均符合 M3
- Drift exercise：IGW 的 `ManagedBy` tag 被手動改為 `Judy`，plan 偵測為 in-place update；apply 恢復後為 `No changes`
- Failure/debug exercise：單一 AZ ID 被 variable validation 阻擋；修正後 validate 與 contract test 通過
- Destroy：`0 added, 0 changed, 21 destroyed`；state 與 AWS 查詢均確認無 M4 orphan
- Rebuild：`21 added, 0 changed, 0 destroyed`；post-rebuild plan 顯示 `No changes`
- Rebuild VPC：`vpc-0147f2cb6a64d58e5`，狀態 `available`
- Rebuild AWS 驗證：CIDR `10.20.0.0/16`、DNS 啟用、4 個 subnet、2 個 AZ、1 個 IGW、1 條 public default route、private Internet route 0、公開 PostgreSQL rule 0、NAT Gateway 0、Elastic IP 0
- 最終決策：保留 rebuilt foundation，作為 M5 的輸入

## 成本與 Known Limitations

- 目前 foundation 的固定月費估算為 `USD 0.00`；未來使用 Internet Gateway 可能產生 data transfer 費用，加入 public IPv4、NAT Gateway、ALB、RDS 或 workload 後亦會另外計費。
- M4 使用 local state，沒有 remote backend、locking、共享 state 或 disaster recovery；進入共享或 production 使用前必須另行設計。
- AWS 登入使用 `aws login` 短期憑證；session 到期後需重新登入。Windows PATH 中舊版 AWS CLI 可能先被命中，因此登入時使用支援 `aws login` 的 2.37.6 執行檔。
- Public subnet 的 `map_public_ip_on_launch` 為 false；M4 沒有 ALB、public ingress rule、NAT/private egress、ECS、RDS、IAM workload roles 或 IPv6 workload design，這些不是本里程碑的缺漏，而是刻意保留給後續里程碑。
- AWS 自動建立的 default security group、main route table，以及 Project 原有的 Default VPC，不由本 Terraform configuration 管理。

## Terraform 常見命名習慣如下：
|--------|------------------------|-------------------------|
| 名稱   | 適合情況                | 意思                    |
|--------|------------------------|-------------------------|
| `main` | 某類資源的主要實例      | 主要的 VPC、IGW          |
| `this` | 使用 `for_each` 批次建立同類資源 | 目前這組資源     |
| `public` | 資源屬於 public 網路層 | Public route table     |
| `private` | 資源屬於 private 網路層 | Private route tables |
| `application` | Application tier | App Security Group    |
| `database` | Database tier       | DB Security Group     |
|--------|------------------------|-------------------------|

### Terraform 是以「resource type + logical name」識別資源。
例如：
aws_vpc.main
aws_internet_gateway.main

### 有 0.0.0.0/0 這條 public default route 就一定可以連上 Internet 嗎？
不一定。Public Internet connectivity 通常還需要：
1. Subnet 關聯 public route table
2. Public route table 有 0.0.0.0/0 → IGW
3. 資源擁有 public IPv4 或 Elastic IP
4. Security Group 允許所需流量
5. Network ACL 允許所需流量
6. 作業系統與應用程式允許流量

目前刻意將 3. public IP 決策留給 M5 的 ALB/workload。

## terraform plan 與 cdk diff 的差異

### Terraform
Terraform 的核心關係是：
Terraform configuration
        ↕
Terraform state
        ↕ refresh
AWS actual resources

執行：
terraform plan
通常會：
讀取 .tf configuration。
讀取 terraform.tfstate。
透過 AWS provider 查詢已管理資源的實際狀態。
更新 Terraform 對現況的理解。
計算 configuration、state、AWS actual resources 的差異。
顯示 create、update、destroy 或 replace。
因此 Terraform plan 對實際資源狀態的參與程度比較直接。

### AWS CDK
CDK 的核心流程是：
TypeScript / Python CDK code
            ↓
         cdk synth
            ↓
CloudFormation template
            ↓
         cdk diff
            ↓
已部署的 CloudFormation stack template

執行：
cdk diff
主要會：
執行 CDK application。
將 constructs synthesize 成 CloudFormation template。
取得已部署 stack 的 CloudFormation template。
比較新舊 template。
顯示預計新增、修改或刪除的差異。

重要差別是：
cdk diff 主要比較「新 synth 的 template」與「CloudFormation 目前管理的 stack template」，不等於完整檢查所有 AWS resource 的實際 drift。

如果有人在 Console 手動修改資源，應使用：
cdk drift <stack-name>
或 CloudFormation drift detection，確認實際資源是否偏離 stack template。

## 常用指令對照
| Terraform | AWS CDK | 用途 |
|---|---|---|
| `terraform init` | `cdk bootstrap`／安裝 dependencies | 準備執行環境，cdk bootstrap 會建立 AWS 資源，而 terraform init 通常只初始化本機工作目錄與 backend connection。|
| `terraform fmt` | Prettier、ESLint、Ruff | 格式化程式碼 |
| `terraform validate` | `cdk synth`、TypeScript compile | 檢查設定能否解析與合成 |
| `terraform test` | Jest、pytest、CDK assertions | Infrastructure unit test |
| `terraform plan` | `cdk diff` | 預覽預計變更 |
| `terraform apply` | `cdk deploy` | 執行部署 |
| `terraform destroy` | `cdk destroy` | 移除受管理資源 |
| `terraform show m4.tfplan` | `cdk diff`／檢視 change set | 查看部署變更 |
| `terraform output` | CloudFormation Outputs | 取得部署輸出 |
| `terraform state list` | `aws cloudformation list-stack-resources` | 列出受管理資源 |
| `terraform state show` | `describe-stack-resource` | 查看受管理資源資料 |
| `terraform import` | `cdk import` | 將既有資源納入管理 |
| `terraform plan` 偵測 drift | `cdk drift` | 檢查實際資源偏移 |
| `terraform apply -replace=...` | CloudFormation replacement | 強制替換資源，CDK 沒有完全相同的常用指令 |

其他差異：
1. Terraform root module ↔ CDK App／Stack
Terraform 同一個 module 內所有 .tf 都會合併成一份 configuration
CDK 的部署單位通常是 Stack

2. Terraform resource ↔ CDK Construct
L1、L2、L3 Construct 是 CDK 特有的重要觀念
L1 Construct：直接對應 CloudFormation resource (大致接近 Terraform 的單一 resource)
L2 Construct：提供較友善的 AWS service abstraction (一般 CDK 開發優先使用 L2)
L3 Construct：代表完整 architecture pattern (Terraform module 比較接近 L3 construct 的概念)

3. 比較實際資源差異語法
| 目的 | Terraform | CDK |
|---|---|---|
| 程式碼預計變更 | `terraform plan` | `cdk diff`(主要比較 template 差異) |
| 實際資源 drift | `terraform plan`(會 refresh 受管理資源並顯示 drift) | `cdk drift`(實際比較 CloudFormation resource drift) |
| 執行部署 | `terraform apply` | `cdk deploy` |

4.總結
terraform plan 和 cdk diff 都用來預覽 IaC 預計造成的新增、修改與刪除；Terraform 透過自己的 state 與 provider refresh 比較實際資源，而 CDK 主要將 synth 後的 CloudFormation template 與已部署 stack template 比較，實際 drift 則另外用 cdk drift 檢查。