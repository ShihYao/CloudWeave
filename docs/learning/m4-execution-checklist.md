# M4 — Terraform AWS Foundation 執行檢查表

- 狀態：已完成並進入 Design Freeze
- 執行者：Judy
- AWS Account ID：665116832947
- AWS Region：ap-southeast-2
- AWS CLI profile：cloudweave-dev
- Availability Zone IDs：apse2-az1、apse2-az3
- 開始日期：2026-10-01
- 完成日期：2026-10-02
- 唯一真相來源：[M3 AWS Foundation Design Freeze](m3-aws-foundation.md)
- Terraform module：[infrastructure/terraform/aws](../../infrastructure/terraform/aws/README.md)

> 完成一項後將 [ ] 改為 [x]，並填寫實際結果。不得記錄 access key、secret key、session token 或其他 credential。

## 0. 範圍與停止條件

M4 只實作 VPC、subnet、route table、Internet Gateway、DNS、tags、Security Group foundation，以及 Terraform plan/apply/verify/drift/destroy/rebuild 學習循環。

M4 不建立 ALB、ECS、Fargate、RDS、NAT Gateway、Elastic IP、Order Service workload 或尚未凍結的 IAM roles。若 plan 出現這些資源、未預期 public exposure、replacement 或 destroy，立即停止，不得 apply。

## 1. 工具與本機設定

- [x] Terraform CLI 已安裝
- [x] AWS CLI 已安裝
- [x] 已確認 infrastructure/terraform/aws 為 Terraform 工作目錄
- [x] .terraform.lock.hcl 存在
- [x] terraform.tfvars、state 與 plan files 已被 Git ignore
- [x] Repository 中沒有 AWS credential

執行指令：

    terraform version
    aws --version
    git status --short

紀錄：

    Terraform version：1.16.4（windows_amd64）
    AWS CLI version：2.37.6（Python 3.14.6，Windows 11）
    Git status：工作樹已有 M4 文件、Terraform configuration 與 Agent Toolkit rules 等未提交變更
    備註：2026-10-01 完成檢查。git check-ignore 已確認 terraform.tfvars、tfstate、tfstate backup、tfplan 與 .terraform 內容皆被忽略；credential pattern 掃描通過，未發現疑似 AWS access key、secret key 或 private key。

## 2. AWS 身分與目標環境

執行指令：

    aws configure list-profiles
    aws sts get-caller-identity --profile <profile>
    aws ec2 describe-availability-zones --region <region> --profile <profile> --query "AvailabilityZones[].{Name:ZoneName,Id:ZoneId,State:State}" --output table

- [x] AWS Account ID 正確
- [x] Caller ARN／principal 正確
- [x] Region 已確認
- [x] 選定兩個不同且狀態為 available 的 AZ ID
- [x] 使用 aws login 的 managed assumed role，不使用 root-user access key
- [x] Credential 未寫入 Terraform 或 repository

紀錄：

    Account ID：665116832947
    Caller ARN：arn:aws:sts::665116832947:assumed-role/AccountFullAccessRole/24488478-f0e1-70b5-fd20-5f300905a180
    Region：ap-southeast-2
    AZ A name / ID：ap-southeast-2a / apse2-az1
    AZ B name / ID：ap-southeast-2b / apse2-az3
    Authentication method：AWS CLI aws login（短期、自動輪替憑證）
    備註：2026-10-01 重新登入並完成唯讀驗證。ap-southeast-2c / apse2-az2 亦為 available，但 M4 依兩 AZ 設計選用前兩個 AZ。

## 3. 本機變數檔

執行：

    Copy-Item terraform.tfvars.example terraform.tfvars

terraform.tfvars 應填入：

    aws_region            = "<region>"
    availability_zone_ids = ["<az-id-a>", "<az-id-b>"]
    aws_profile           = "<profile>"
    environment           = "learning"

- [x] Region 與 AWS CLI 驗證結果相同
- [x] AZ IDs 屬於所選 Region
- [x] environment 為 learning
- [x] 檔案不含 credential
- [x] git status 未顯示 terraform.tfvars

紀錄：

    完成時間：2026-10-01
    備註：terraform.tfvars 已設定 cloudweave-dev、ap-southeast-2、apse2-az1、apse2-az3 與 learning；git check-ignore 與 credential scan 均通過。

## 4. Format、初始化、驗證與測試

執行：

    terraform fmt -check -recursive
    terraform init -backend=false -input=false (初始化 providers 與 modules，但這一次不要初始化 backend)
    terraform validate
    terraform test -test-directory=tests

    屬於靜態檢查，這些工作不需要真實 state backend，避免本機驗證階段碰觸到遠端

- [x] terraform fmt 通過
- [x] terraform init 成功
- [x] terraform validate 通過
- [x] Contract test 為 1 passed, 0 failed

    fmt
    確認程式碼格式
    ↓
    init
    準備 Terraform 工作環境與 provider
    預設使用 local backend，放在當前目錄 infrastructure/terraform/aws/terraform.tfstate
    通常團隊會使用 romte backend，如 s3，將 state 放在遠端保存與管理
    ↓
    validate
    檢查 configuration 語法與引用
    ↓
    test
    Terraform 原生測試檔，放在當前目錄 infrastructure/terraform/aws/tests/foundation.tftest.hcl
    (用假的 AWS provider response 產生測試 plan，不連線建立真實 AWS 資源)
    確認是否符合 M3 Design Freeze 的核心條件

紀錄：

    執行時間：2026-10-01
    測試結果：Success，1 passed, 0 failed
    Warnings：無
    備註：Terraform 1.16.4；AWS provider 6.66.0 由 .terraform.lock.hcl 鎖定並重用。未執行 AWS plan 或 apply。

## 5. 真實 Plan

會檢查在真實 AWS project 中將發生什麼
先正常初始化 backend，再產生並查看 saved plan：

    terraform init
    terraform plan -out m4.tfplan
    terraform show m4.tfplan

- [x] Plan 成功產生
- [x] Plan file 未被 Git 追蹤
- [x] 已完整閱讀 plan

terraform plan 只產生「執行提案」：
    目前 state
    +
    實際 AWS 狀態
    +
    Terraform configuration
    =
    預計執行的 changes

紀錄：

    Plan: 21 to add, 0 to change, 0 to destroy
    產生時間：2026-10-01
    備註：terraform init 已正常初始化 local backend；m4.tfplan 使用 Terraform 1.16.4、plan format 1.2。JSON review 確認 21 個 resource actions 全為 create，plan file 已被 Git ignore。尚未執行 apply。

    Plan: 21 to add, 0 to change, 0 to destroy.

## 6. Plan Review 與成本檢查

預期 foundation：

- [x] 1 個 VPC，CIDR 為 10.20.0.0/16
- [x] DNS support 與 DNS hostnames 均啟用
- [x] Tenancy 為 default
- [x] 4 個 subnet，CIDR 與 M3 相同
- [x] Public/private subnet 分布在兩個 AZ
- [x] map_public_ip_on_launch 為 false
- [x] 1 個 Internet Gateway
- [x] 1 張 public route table
- [x] 2 張 private route table
- [x] Public route 為 0.0.0.0/0 到 IGW
- [x] 4 個 route-table associations 正確
- [x] Private route tables 沒有 Internet default route
- [x] 3 個 Security Groups
- [x] Ingress SG 到 Application SG 僅 TCP 8080
- [x] Application SG 到 Database SG 僅 TCP 5432
- [x] Database SG 沒有公開 PostgreSQL
- [x] Tags 完整

不得出現：

- [x] 沒有 NAT Gateway 或 Elastic IP
- [x] 沒有 ALB、ECS、RDS 或 workload
- [x] 沒有寬泛 IAM policy
- [x] 沒有未預期 public exposure
- [x] 沒有未預期 change、destroy 或 replacement
- [x] 沒有其他未預期計費資源

Review 結論：

    [x] APPROVED — 技術與成本 review 通過；仍須 Judy 明確確認後才可 apply
    [ ] REJECTED — 不得 apply
    Reviewer：Codex
    Review 時間：2026-10-01 15:45（Asia/Taipei）
    異常與處置：無 plan 異常。第一次自動審查因 PowerShell 單一物件 Count 與 tag scope 判定產生假失敗；修正審查腳本後全部通過，Terraform plan 本身未變更。
成本估算（2026-10-01，public on-demand pricing，不含稅）：

    固定月費：USD 0.00
    Apply 當下預估 usage cost：USD 0.00
    計費風險：未來 workload 若使用 Internet Gateway 會有 data transfer 費；新增 public IPv4、NAT Gateway、ALB、RDS 等也會另外計費。
    依據：AWS VPC 本身無額外費用、Internet Gateway 無小時費、Security Group 無額外費；plan 中沒有任何已知計費元件或 workload。
    官方來源：https://docs.aws.amazon.com/vpc/latest/userguide/
    官方來源：https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html
    官方來源：https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html

## 7. Apply

執行：

    terraform apply m4.tfplan
    terraform output

不得使用 -auto-approve，也不得套用未經 review 的新 plan。

- [x] 套用的是已 review 的 m4.tfplan
- [x] Apply 成功
- [x] 沒有未預期 warning 或 error
- [x] Outputs 已記錄

紀錄：

    Apply 時間：2026-10-01（Asia/Taipei）
    Apply 摘要：21 added, 0 changed, 0 destroyed21 added, 0 changed, 0 destroyed
    Post-apply 驗證：terraform plan 顯示 No changes；state 共追蹤 21 個 resource instances
    VPC ID：vpc-0ed9d8f4da8547b5c
    Public subnet IDs：public-a = subnet-0e30c87a36906e574；public-b = subnet-0a6e5d484cfdaa564
    Private subnet IDs：private-a = subnet-0f82631d0c4397bb6；private-b = subnet-03c59831d6b7aed6e
    Security Group IDs：ingress = sg-08a35ff6bb2237598；application = sg-09d85a66437aae53c；database = sg-0e26c0db2f193ca5b
    Route table IDs：public = rtb-0194d3d3a89f98f87；private-a = rtb-0d90d1ea171dd36a1；private-b = rtb-035aca4d457168a7b
    Warnings／errors：Apply 無 warning 或 error。後續 AWS CLI 身分複查時，cloudweave-dev 的短期憑證已不可用；再次查詢 AWS 前需重新執行 aws login。

## 8. AWS 實際資源驗證

- [x] VPC CIDR 正確
- [x] DNS support 與 hostnames 啟用
- [x] 4 個 subnet CIDR 正確
- [x] AZ name／ID 分布正確
- [x] Internet Gateway 掛載至正確 VPC
- [x] Public default route 指向 IGW
- [x] Private route tables 沒有 Internet default route
- [x] 所有 subnet associations 正確
- [x] 三個 Security Groups 與規則正確
- [x] 沒有公開 PostgreSQL rule
- [x] Tags 正確
- [x] 沒有 NAT Gateway 或 Elastic IP

證據：

    驗證時間：2026-10-01（Asia/Taipei）
    使用方式（CLI／Console）：AWS CLI 2.37.6，profile cloudweave-dev，Region ap-southeast-2
    CLI output 或 screenshot 路徑：本節紀錄（AWS CLI 即時查詢）
    驗證身分：Project 665116832947；arn:aws:sts::665116832947:assumed-role/AccountFullAccessRole/24488478-f0e1-70b5-fd20-5f300905a180
    驗證結果：Post-rebuild terraform plan 顯示 No changes。AWS CLI 驗證 VPC vpc-0147f2cb6a64d58e5 為 available；CIDR、DNS、4 個 subnet、兩個 AZ、IGW、routes、3 個 managed SG 與 tags 均符合設計；private Internet route 0、公開 PostgreSQL rule 0、NAT Gateway 0、Elastic IP 0。VPC 10.20.0.0/16、DNS support/hostnames、4 個 subnet、兩個 AZ、IGW、routes、associations、三個 managed SG、PostgreSQL rule 與 tags 全部符合設計；NAT Gateway 與 Elastic IP 均為 0。
    發現差異：無設計差異。AWS 自動建立的 default security group 與 main route table 不屬於 Terraform-managed M4 資源，屬正常 VPC 內建元件。
    處置：不需處置；未修改任何 AWS 資源。

## 9. Terraform State 練習

執行：

    terraform state list
    terraform state show aws_vpc.main
    terraform state show 'aws_subnet.this[\"public-a\"]'
    terraform show

- [x] 已列出所有 state resources
- [x] 已查看 VPC 與至少一個 subnet
- [x] 已比較 configuration、state 與 AWS actual resource
- [x] 沒有手動修改 terraform.tfstate
- [x] State 未提交版本控制

紀錄：

    State resource 數量：21
    觀察：
    terraform state list 顯示每個 for_each instance 都有獨立 address，例如 aws_subnet.this["public-a"]。

    terraform state show 除了 configuration 中設定的 CIDR、AZ、tags 與 map_public_ip_on_launch，也會顯示 AWS/provider 回填的 id、ARN、owner_id、available IP count、tags_all 等 computed attributes。

    在 Windows PowerShell 查詢含字串 key 的 instance 時，需使用 terraform state show 'aws_subnet.this[\"public-a\"]'，才能把 key 的雙引號正確傳給 Terraform。

    Configuration / State / Actual 的差異：
    Configuration 是 .tf 宣告的 desired state；State 保存 Terraform 管理的 21 個 resource instances、AWS IDs 與已知屬性；Actual 是 AWS API 回傳的真實資源。

    Post-apply terraform plan 顯示 No changes，因此三者目前沒有 drift。

    State／Actual 會比 configuration 多出 AWS/provider 自動計算的欄位；AWS 自動建立的 default security group 與 main route table，以及原有 Default VPC，未由本 configuration 管理，因此不在 Terraform state 中，這屬預期差異。

    terraform state list 結果：
aws_internet_gateway.main
aws_route.public_ipv4_default
aws_route_table.private["a"]
aws_route_table.private["b"]
aws_route_table.public
aws_route_table_association.private["private-a"]
aws_route_table_association.private["private-b"]
aws_route_table_association.public["public-a"]
aws_route_table_association.public["public-b"]
aws_security_group.application
aws_security_group.database
aws_security_group.ingress
aws_subnet.this["private-a"]
aws_subnet.this["private-b"]
aws_subnet.this["public-a"]
aws_subnet.this["public-b"]
aws_vpc.main
aws_vpc_security_group_egress_rule.application_to_database
aws_vpc_security_group_egress_rule.ingress_to_application
aws_vpc_security_group_ingress_rule.application_from_ingress
aws_vpc_security_group_ingress_rule.database_from_application

## 10. Drift Experiment

只修改低風險 tag，不修改 CIDR、route、SG rule 或 IGW attachment。

流程：在 AWS Console 修改測試 tag，執行 terraform plan，記錄 drift，再以 terraform apply 恢復，最後確認 terraform plan 顯示 no changes。

- [x] 已建立低風險 drift
- [x] Plan 成功偵測 drift
- [x] 已判斷是 update、replace 或 destroy
- [x] 已恢復 desired state
- [x] 最終 plan 顯示 no changes

紀錄：

    修改的 resource：cloudweave-learning-igw 的 Tag
    修改前：ManagedBy=Terraform
    手動修改後：ManagedBy=Judy
    Plan 顯示：cd C:\Users\judy9\CloudWeave\infrastructure\terraform\aws -> terraform plan
    Terraform will perform the following actions:

  # aws_internet_gateway.main will be updated in-place
  ~ resource "aws_internet_gateway" "main" {
        id       = "igw-0ef961695ae298520"
      ~ tags     = {
          - "ManagedBy" = "Judy" -> null
            "Name"      = "cloudweave-learning-igw"
        }
      ~ tags_all = {
          ~ "ManagedBy"   = "Judy" -> "Terraform"
            # (4 unchanged elements hidden)
        }
        # (4 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.

    恢復方式：terraform apply
    最終結果：aws_internet_gateway.main: Modifications complete after 1s [id=igw-0ef961695ae298520]
            Apply complete! Resources: 0 added, 1 changed, 0 destroyed.

            再次 terraform plan，結果：No changes. Your infrastructure matches the configuration.

## 11. Failure／Debug Exercise

建議暫時讓 availability_zone_ids 只包含一個值，觸發 variable validation；不要破壞真實 AWS 網路。

- [X] 已記錄預期 failure
- [X] 已取得錯誤訊息
- [X] 已判斷 root cause
- [X] 已修正 input
- [X] 修正後 validate 通過
- [X] 修正後 contract test 通過

紀錄：

    Failure scenario：
    暫時將 AZ IDs 覆寫成只有一個值
    terraform plan -refresh=false -input=false -var='availability_zone_ids=[\"apse2-az1\"]'

    錯誤訊息：
    Error: Invalid value for variable

    var.availability_zone_ids is list of string with 1 element

    availability_zone_ids must contain exactly two distinct AZ IDs.

    This was checked by the validation rule at variables.tf:20,3-13.

    Root cause：variables.tf 規則敘述 "必須剛好提供兩個 AZ ID"
    修正：此次不傳參數，直接執行 terraform validate
    預防方式：保留 variable validation，並在變更前執行 terraform validate、terraform test 與 terraform plan

## 12. Destroy

執行：

    terraform plan -destroy -out m4-destroy.tfplan
    terraform show m4-destroy.tfplan
    terraform apply m4-destroy.tfplan

- [x] Destroy plan 已完整 review
- [x] 只包含 M4 管理的資源
- [x] Destroy 成功
- [x] AWS 已確認資源移除
- [x] 沒有 orphan 或計費資源

紀錄：

    Destroy plan 摘要：0 added, 0 changed, 21 destroyed；state 21、destroy 21、非 delete action 0、遺漏 0、額外 0。只包含 M4 Terraform-managed resources，原有 Default VPC 不在 plan 中。刪除操作預估 USD 0.00，刪除後固定月費預估 USD 0.00。
    Destroy 時間：2026-10-02 01:00（Asia/Taipei）
    AWS 驗證結果：Terraform state 為空；ap-southeast-2 中 Project=CloudWeave、Milestone=M4 的 VPC 查詢結果為 0。原 VPC vpc-0ed9d8f4da8547b5c 與其 subnet、route table、IGW、security groups 已移除。
    殘留資源：無 M4 orphan；NAT Gateway 0、Elastic IP 0。原有 AWS Default VPC 不屬於 M4，已保留。

## 13. Rebuild 與可重現性

執行：

    terraform plan -out m4-rebuild.tfplan
    terraform show m4-rebuild.tfplan
    terraform apply m4-rebuild.tfplan

- [x] Rebuild plan 與 M3 一致
- [x] Rebuild plan 已 review
- [x] Rebuild apply 成功
- [x] AWS resources 已重新驗證
- [x] Rebuild 後 plan 顯示 no changes
- [x] 已決定最終保留或再次 destroy

紀錄：

    Rebuild 時間：2026-10-02 14:45（Asia/Taipei）
    Plan 摘要：21 added, 0 changed, 0 destroyed；21 個 action 全為 create，禁止資源類型 0。Region ap-southeast-2、VPC CIDR 10.20.0.0/16、AZ IDs apse2-az1／apse2-az3，與 M3/M4 設計一致。固定月費預估 USD 0.00，Apply 當下預估 USD 0.00。
    Apply 摘要：21 added, 0 changed, 0 destroyed
    驗證結果：Post-rebuild terraform plan 顯示 No changes。AWS CLI 驗證 VPC vpc-0147f2cb6a64d58e5 為 available；CIDR、DNS、4 個 subnet、兩個 AZ、IGW、routes、3 個 managed SG 與 tags 均符合設計；private Internet route 0、公開 PostgreSQL rule 0、NAT Gateway 0、Elastic IP 0。
    最終資源處置：保留 rebuilt M4 foundation。
    原因：作為 M5 workload foundation；目前固定月費預估 USD 0.00，後續新增計費資源前仍須 plan 與成本 review。

## 14. 文件與 M4 Freeze Gate

- [x] 本檢查表已完整填寫
- [x] M4 learning note 已更新驗證證據
- [x] Authentication 與 state strategy 已記錄
- [x] Plan/apply/AWS verification 已記錄
- [x] Drift 與 debug exercise 已記錄
- [x] Destroy/rebuild 已記錄
- [x] Known limitations 已記錄
- [x] Repository 沒有 credential、state、tfvars 或 saved plan
- [x] 最終 fmt、validate 與 contract test 通過
- [x] Git diff 已 review
- [x] 沒有偷渡 M5 workload resource

最終結論：

    [ ] M4 尚未完成
    [x] M4 已完成並可進入 Design Freeze
    完成者：Judy
    Review 者：Codex
    日期：2026-10-02
    Known limitations：Local state 無 remote locking／共享／DR；AWS login 為短期 session；M4 刻意不含 public ingress、NAT/private egress、ALB、ECS、RDS、workload IAM roles 與 IPv6 workload design。
    M5 handoff：保留 VPC vpc-0147f2cb6a64d58e5 與 M4 foundation。M5 必須沿用 Terraform 管理，使用 outputs／state 取得新 resource IDs；任何 apply 或 destroy 前仍須 review plan 與預估成本。
