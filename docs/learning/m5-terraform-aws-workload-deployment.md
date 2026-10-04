# M5 — Terraform AWS Workload Deployment

- 狀態：部署前參照版（IMPLEMENT、PLAN 已完成；尚未 APPLY／DEPLOY／VERIFY）
- AWS project：665116832947
- selected Region：`ap-southeast-2`
- Environment：`learning`
- Image tag：`m5-v1`
- Foundation：沿用已 Freeze 的 M3/M4 VPC、subnets、routes 與三層 Security Groups

> 本文件只把已由 Terraform configuration 與 saved plan 證明的內容寫成事實。需要真實 AWS runtime 才能確認的項目標為「待驗證」，避免把 `terraform apply succeeded` 誤當成 end-to-end 成功。

## 1. M5 要解決什麼

M5 不新增 Order business feature，而是把 M1/M2 的 Spring Boot Order Service 與 PostgreSQL workload 部署到 M4 的 AWS foundation：

```text
Internet
  │ HTTP :80（learning only）
  ▼
Application Load Balancer
  │ HTTP :8080，source = ALB Security Group
  ▼
ECS Service
  │ 維持 desired_count = 1
  ▼
Fargate Task / awsvpc ENI / public IPv4
  │ Spring Boot :8080
  │ PostgreSQL :5432，source = Application Security Group
  ▼
RDS for PostgreSQL（private subnets）
```

目前 plan 是 `15 to add, 0 to change, 0 to destroy`。既有 M4 resources 全部 `no-op`，沒有 replace。

## 2. Learning deployment 與 production reference

| 決策 | M5 learning deployment | Production reference |
|---|---|---|
| ECS placement | 兩個 public subnets，單一 task 由 ECS 選擇 AZ | Private subnets，至少跨兩 AZ tasks |
| Task public IP | `assign_public_ip = true` | `false` |
| Outbound | IGW + task public IPv4；Application SG 允許 TCP 443 outbound | 每 AZ NAT Gateway，或完整且經成本評估的 VPC endpoints |
| Listener | HTTP 80 | HTTPS 443 + ACM certificate，HTTP redirect |
| ECS desired count | 1 | 至少 2，跨 AZ |
| RDS | Single-AZ `db.t4g.micro` | 依 RTO/RPO 選 Multi-AZ、較大 instance與正式容量 |
| Backup | 1 day | 依 retention policy 延長並測試 restore |
| Deletion protection | 關閉 | 開啟 |
| Final snapshot | destroy時跳過 | 必須保留並具明確命名／retention |
| Logs | 7 days | 依稽核與營運需求延長 |

選 public task 是刻意的 portfolio cost decision，不代表 production-grade Internet security。Task 雖然有 public IPv4，但 Application SG 沒有 Internet ingress；8080 只接受 ALB SG。

## 3. 新增的 AWS services 與 Terraform resources

### Amazon ECR

- `aws_ecr_repository.order_service`
- `aws_ecr_lifecycle_policy.order_service`
- Repository：`cloudweave-learning-order-service`
- Image tags immutable，避免同一 tag 被覆寫成不同內容。
- Lifecycle policy只保留最新十個 images。
- ECR 管 infrastructure/image storage；Docker負責 build；未提前實作 CI/CD。

### Amazon RDS for PostgreSQL

- `aws_db_subnet_group.order`
- `aws_db_instance.order`
- PostgreSQL 17、`db.t4g.micro`、20 GiB gp3、encrypted storage。
- DB subnet group只使用兩個 private subnets。
- `publicly_accessible = false`、Single-AZ、1-day backup。
- Database schema不由 Terraform 建 table，而由 application startup時的 Flyway migration建立。

### AWS Secrets Manager

沒有獨立宣告 `aws_secretsmanager_secret`。`manage_master_user_password = true` 讓 RDS產生 master password並將 credential交給 Secrets Manager管理。

### Amazon ECS / AWS Fargate

- `aws_ecs_cluster.order`
- `aws_ecs_task_definition.order_service`
- `aws_ecs_service.order`
- Fargate task：0.5 vCPU、1 GiB memory、Linux x86_64、`awsvpc`。
- ECS service維持一個 running task，開啟 deployment circuit breaker與 rollback。

### Application Load Balancer

- `aws_lb.order`
- `aws_lb_target_group.order`
- `aws_lb_listener.http`
- Internet-facing ALB位於兩個 public subnets。
- Fargate使用自己的 ENI，因此 target type必須是 `ip`，不是 `instance`。

### CloudWatch Logs

- `aws_cloudwatch_log_group.order_service`
- Log group：`/ecs/cloudweave-learning-order-service`
- Retention：7 days。
- 目的只涵蓋 M5 application startup與failure troubleshooting；完整 observability留到 M14。

### IAM

- `aws_iam_role.ecs_task_execution`
- `aws_iam_role_policy.ecs_task_execution`
- Execution Role由 ECS/Fargate runtime使用：拉 ECR image、寫 CloudWatch Logs、讀 DB secret。
- M5 Order Service不呼叫 AWS API，因此沒有建立 Task Role。

## 4. ECS 五個概念的關係

```text
ECS Cluster
  └─ ECS Service（維持 desired_count）
       └─ Task（實際 running instance）
            └─ Container（Spring Boot process）

Task Definition
  └─ Task 的 immutable workload blueprint
```

- Cluster是 workload的邏輯邊界，不是 EC2 server。
- Task Definition描述 image、CPU、memory、ports、environment、secrets、logging與roles。
- Task是某個 Task Definition revision的實際執行個體。
- Service監控 task；task停止或不健康時，Service會嘗試補回 desired count。
- Container是 Task內真正執行 `java -jar app.jar` 的 process。

## 5. Container image flow

Terraform不 build image。第一次部署有明確 bootstrap boundary：

```text
Terraform apply ECR prerequisite
  ↓
docker build cloudweave-order-service:m5-v1
  ↓
aws ecr get-login-password | docker login
  ↓
docker tag local-image ECR-URL:m5-v1
  ↓
docker push ECR-URL:m5-v1
  ↓
重新 terraform plan / review
  ↓
terraform apply workload plan
  ↓
Fargate execution role取得 ECR auth並拉取 image
```

不能在 image尚不存在時先建立 service，再把 task反覆啟動失敗當成部署流程。

## 6. Client request traffic flow

```text
Client
  → ALB DNS
  → ALB listener :80
  → Target Group :8080
  → Task ENI private IP :8080
  → Spring Boot container
```

逐跳判斷：

1. Client透過 public DNS解析 ALB名稱。
2. Public subnet route有 `0.0.0.0/0 → Internet Gateway`。
3. Ingress SG允許 Internet到 TCP 80。
4. Listener把 request forward至 target group。
5. Target group用 task ENI private IP註冊 target。
6. Ingress SG只允許 TCP 8080 egress到 Application SG。
7. Application SG只允許來自 Ingress SG的 TCP 8080 ingress。
8. Spring Boot在 container port 8080監聽並處理 request。

「Task有 public IP」不是 client traffic正常路徑。Client應只走 ALB；Application SG不允許 Internet直接打 8080。

## 7. Database traffic flow

```text
Spring Boot
  → 解析 RDS private DNS endpoint
  → DB_URL: jdbc:postgresql://<rds-address>:5432/cloudweave
  → VPC local route 10.20.0.0/16
  → Database SG檢查 source = Application SG
  → PostgreSQL :5432
```

- Task與RDS即使位於不同 subnets，VPC local route仍提供路徑。
- Database SG不依賴 task固定 IP；task被替換、ENI/private IP改變後，SG reference仍有效。
- RDS沒有 public IPv4，也沒有 `0.0.0.0/0 → 5432` rule。

## 8. Task outbound flow

Task啟動與運作需要存取 ECR、S3 image layers、CloudWatch Logs與Secrets Manager：

```text
Task ENI
  → Application SG TCP 443 egress
  → public subnet default route
  → Internet Gateway（透過 task public IPv4）
  → AWS public service endpoint
```

這是 M5 learning egress。M4 private route tables仍沒有 NAT或Internet default route，也沒有被偷偷修改。

## 9. Secret flow與暴露面

```text
RDS產生 username/password
  → Secrets Manager儲存 credential
  → Terraform取得 secret ARN（不是 secret value）
  → Task Definition以 ARN + JSON key參照 username/password
  → ECS execution role呼叫 secretsmanager:GetSecretValue
  → ECS在 container啟動時注入 DB_USERNAME / DB_PASSWORD
  → Spring Boot讀取 environment variables
```

Terraform state包含：RDS username、secret ARN、DB endpoint、Task Definition中的 secret references。Terraform state不包含由 RDS產生的 password value。

可能看到 secret value的位置：

- 具有 `secretsmanager:GetSecretValue`權限的人員或role。
- ECS runtime取得後的 container process environment。
- Application若錯誤記錄 environment或exception detail，可能造成洩漏；CloudWeave不得這樣做。

不會看到 password的位置：Git、Terraform code、tfvars、Docker image、Terraform outputs、一般 ECS Task Definition顯示。

Secret rotation後，已執行的 task不會自動取得新值；必須部署／replace task。

## 10. Execution Role vs Task Role

| Role | CloudWeave M5用途 | 是否存在 |
|---|---|---|
| Execution Role | Fargate拉 ECR image、寫 logs、在啟動時取得 secret | 是 |
| Task Role | Spring Boot runtime自行呼叫 AWS API | 否 |

JDBC連線RDS不需要 Task Role；它使用網路路徑與database credential，不是呼叫 AWS control-plane API。

## 11. Health model

Order Service加入 Spring Boot Actuator，只對外 expose `health` endpoint且不顯示 detail：

```text
GET /actuator/health
```

ALB target group每30秒以 HTTP檢查 port 8080，預期 status 200。

- Application health：Spring Boot是否能接受 request，以及health contributors是否正常。
- ALB target health：ALB最近的 `/actuator/health` probes結果。
- ECS Service health：Service結合 task狀態與ALB target health，維持 desired count。
- Container health：Task Definition目前沒有額外 Docker-style health command；M5以ALB health作為服務流量與replacement signal。

Health endpoint不建立 Order，也不改變 business data。

## 12. Flyway startup flow

```text
Fargate啟動 container
  → ECS注入 DB_URL / DB_USERNAME / DB_PASSWORD
  → Spring Boot建立 DataSource
  → 連線 RDS PostgreSQL
  → Flyway讀取 db/migration/V1__create_orders_table.sql
  → 建立 flyway_schema_history與 orders table
  → JPA ddl-auto=validate驗證 schema
  → Application ready
  → ALB health check轉為 healthy
```

不得手動登入RDS建 table。部署後必須從 CloudWatch Logs驗證 Flyway與application ready流程。

## 13. Terraform dependency graph

主要 implicit dependencies：

```text
RDS → DB Subnet Group → private subnets
RDS → Database SG
Task Definition → ECR repository
Task Definition → RDS endpoint / RDS-managed secret
Task Definition → execution role / log group
ECS Service → ECS cluster / Task Definition / Target Group
ALB → public subnets / Ingress SG
Target Group → VPC
```

ECS Service另有兩個有理由的 explicit dependencies：

- Listener必須先存在，Service才開始向已連結ALB的 target group註冊。
- Execution Role inline policy必須先完成，Task才應開始 pull image／logs／secret bootstrap。

其餘關係以resource references形成 implicit dependency，不濫用 `depends_on`。

## 14. Cost checkpoint

即使沒有任何 API request，以下仍可能持續計費：

- ALB小時費與LCU。
- RDS instance與20 GiB storage。
- 一個持續running的Fargate task。
- ALB與Fargate所使用的public IPv4。
- Secrets Manager secret。
- CloudWatch Logs storage／ingestion。
- ECR image storage。

沒有 NAT Gateway費用。短期learning session結束後，不應讓ALB、RDS與Fargate無意義地24/7運行。

## 15. Apply前與部署後驗證

Apply前：

- [x] `terraform fmt -recursive`
- [x] `terraform validate`
- [x] Terraform contract test
- [x] Java unit tests → 1 passed, 0 failed
- [x] Plan為15 add、0 change、0 destroy
- [x] M4 resources沒有replace/change
- [x] 沒有public PostgreSQL
- [x] IAM沒有application Task Role或`Action = *`
- [X] 確認AWS project plan與成本接受
- [X] Apply ECR prerequisite

先只規劃 ECR：
terraform plan `
  -target=aws_ecr_repository.order_service `
  -target=aws_ecr_lifecycle_policy.order_service `
  -out=m5-ecr.tfplan
  → 2 to add, 0 to change, 0 to destroy

  terraform apply m5-ecr.tfplan

建置與推送 Docker image：
docker build --platform linux/amd64 `
  -t 665116832947.dkr.ecr.ap-southeast-2.amazonaws.com/cloudweave-learning-order-service:m5-v1 .
取得 ECR 短效登入 token 後推送：
aws ecr get-login-password ...
docker push 665116832947.dkr.ecr.ap-southeast-2.amazonaws.com/cloudweave-learning-order-service:m5-v1
確認 m5-v1 已存在：
aws ecr describe-images ...
建立完整 M5 資源：
terraform plan -out=m5-full.tfplan
  → 13 to add, 0 to change, 0 to destroy
  terraform apply m5-full.tfplan
觀察到的流程是：
RDS creating
→ RDS backing-up
→ RDS available
→ ECS task pending
→ ECS task running
→ ECS deployment completed
→ ECS service steady state
部署後一致性檢查，重新執行：
terraform plan -detailed-exitcode
terraform output -json
結果：
No changes. Your infrastructure matches the configuration.

部署後待驗證：

- [X] ECR存在 `m5-v1` image。
& $Aws ecr describe-images `
  --repository-name $Repository `
  --image-ids imageTag=m5-v1 `
  --region $Region `
  --profile $Profile `
  --query "imageDetails[0].{Tags:imageTags,Digest:imageDigest,Size:imageSizeInBytes,PushedAt:imagePushedAt}" `
  --output table
|  Digest  |  sha256:3bee3577459036f6b39d7b945e03bdda7c9ccbfec1e0a57522ebf9679cadd5a1   |
|  PushedAt|  2026-10-04T21:28:16.708000+08:00                                          |
|  Size    |  124700469                                                                 |

- [X] ECS Service desired/running count都是1。
& $Aws ecs describe-services `
  --cluster $Cluster `
  --services $Service `
  --region $Region `
  --profile $Profile `
  --query "services[0].{Status:status,Desired:desiredCount,Running:runningCount,Pending:pendingCount,Rollout:deployments[0].rolloutState}" `
  --output table
  ----------------------------------------------------------
|                    DescribeServices                    |
+---------+----------+------------+-----------+----------+
| Desired | Pending  |  Rollout   |  Running  | Status   |
+---------+----------+------------+-----------+----------+
|  1      |  0       |  COMPLETED |  1        |  ACTIVE  |
+---------+----------+------------+-----------+----------+

- [X] Task有獨立 ENI、private IP與learning public IP。
& $Aws ec2 describe-network-interfaces `
  --network-interface-ids $EniId `
  --region $Region `
  --profile $Profile `
  --query "NetworkInterfaces[0].{ENI:NetworkInterfaceId,PrivateIP:PrivateIpAddress,PublicIP:Association.PublicIp,Subnet:SubnetId,Status:Status}" `
  --output table

- [X] Target health為healthy。
health endpoint:
curl.exe -i "$BaseUrl/actuator/health"
HTTP/1.1 200 OK

- [X] RDS為available且publicly accessible為No。
& $Aws rds describe-db-instances `
  --db-instance-identifier $Database `
  --region $Region `
  --profile $Profile `
  --query "DBInstances[0].{Status:DBInstanceStatus,PubliclyAccessible:PubliclyAccessible,Endpoint:Endpoint.Address,Port:Endpoint.Port,AZ:AvailabilityZone,Encrypted:StorageEncrypted}" `
  --output table

- [X] CloudWatch Logs可看到Flyway與application ready。
2026-10-04T13:37:38 2026-10-04T13:37:38.285Z  INFO 1 --- [order-service] [           main] o.f.c.i.s.JdbcTableSchemaHistory
: Creating Schema History table "public"."flyway_schema_history" ...
2026-10-04T13:37:38 2026-10-04T13:37:38.900Z  INFO 1 --- [order-service] [           main] o.f.core.internal.command.DbMigrate
: Migrating schema "public" to version "1 - create orders table"
2026-10-04T13:37:39 2026-10-04T13:37:39.197Z  INFO 1 --- [order-service] [           main] o.f.core.internal.command.DbMigrate
: Successfully applied 1 migration to schema "public", now at version v1 (execution time 00:00.102s)

- [X] `POST /api/v1/orders`可建立Order。
$CreateBody = @{
  totalAmount = 125.50
  currency    = "TWD"
} | ConvertTo-Json

$CreatedOrder = Invoke-RestMethod `
  -Method Post `
  -Uri "$BaseUrl/api/v1/orders" `
  -ContentType "application/json" `
  -Body $CreateBody

$CreatedOrder | Format-List
>>> orderId: 531bb24c-8a92-433c-be80-b816cd6d32b2

$OrderId = "531bb24c-8a92-433c-be80-b816cd6d32b2"
$OrderId

- [X] `GET`可讀回相同Order。
$FetchedOrder = Invoke-RestMethod `
  -Method Get `
  -Uri "$BaseUrl/api/v1/orders/$OrderId"

$FetchedOrder | Format-List

- [X] confirm/cancel state transitions符合M1 contract。
  status : CONFIRMED
curl.exe -sS `
  -o NUL `
  -w "HTTP %{http_code}`n" `
  -X POST `
  "$BaseUrl/api/v1/orders/$ConfirmId/cancel"
CONFIRMED → CANCEL 應回 409
curl.exe -sS `
  -o NUL `
  -w "HTTP %{http_code}`n" `
  -X POST `
  "$BaseUrl/api/v1/orders/$ConfirmId/cancel"
  → HTTP 409

- [X] Task replacement後仍可讀取原Order。
證明資料存在 RDS，不依附原本的 Fargate Task

## 16. Console對照路徑

- ECR → Repositories → `cloudweave-learning-order-service` → Images。
- ECS → Clusters → `cloudweave-learning-order` → Services／Tasks。
- ECS → Task definitions → `cloudweave-learning-order-service` → revision。
- ECS Task → Networking → ENI、private/public IP、subnet、Security Group。
- EC2 → Load Balancers → `cloudweave-learning-order-alb`。
- EC2 → Target Groups → `cloudweave-learning-order-tg` → Targets／Health status。
- RDS → Databases → `cloudweave-learning-order-db` → Connectivity & security。
- VPC → Security Groups → ingress/application/database chain。
- CloudWatch → Log groups → `/ecs/cloudweave-learning-order-service`。
- Secrets Manager → RDS-managed secret；不要把Retrieve secret value畫面貼入文件或聊天。

## 17. Debug順序

遇到 timeout、unhealthy或task反覆重啟時，依下列順序縮小範圍：

```text
DNS
→ Route / subnet placement
→ Security Group source/destination/port
→ ALB target health與reason code
→ ECS service events與stopped task reason
→ CloudWatch application/Flyway logs
→ RDS status、endpoint與database connectivity
```

不要先猜 root cause，也不要因DNS可解析就假設route與SG一定正確。

## 18. 預定 failure experiment

部署並完成baseline驗證後，暫時把ALB target group health check path改成不存在的path，再透過Terraform套用；預期target變成unhealthy、ALB無healthy targets、ECS events與target health reason提供證據。Restore時把path改回 `/actuator/health`並重新apply。

實驗開始前只觀察symptom與evidence，不提前公布root cause；完成debug後再記錄推理過程。

## 19. Persistence experiment

1. 透過ALB建立Order並記錄orderId。
2. 強制ECS Service進行new deployment或停止目前task，讓Service建立replacement task。
3. 確認新task具有不同task ARN／ENI／IP。
4. 使用相同orderId執行GET。
5. 若資料仍存在，即證明compute lifecycle與database lifecycle分離。

這對應M2的概念：Docker container可以被替換，而PostgreSQL named volume保留資料；M5則由RDS獨立於Fargate task保存資料。

## 20. Destroy strategy

Destroy前先執行並review：

```text
terraform plan -destroy -out m5-destroy.tfplan
terraform show m5-destroy.tfplan
```

目前learning設定的預期：

- RDS：destroy，`skip_final_snapshot = true`，資料不可恢復。
- RDS-managed secret：隨RDS lifecycle處理，需在AWS確認是否進入scheduled deletion。
- ECS/ALB：destroy並停止持續費用。
- CloudWatch Log Group：destroy，logs不可恢復。
- ECR：repository非空時可能阻止destroy；需先明確刪除images，不能假設Terraform會默默清空。
- M4 Foundation：與M5在同一root module；完整 `terraform destroy`也會刪除M4。若只結束M5而要保留Foundation，必須先設計並review精確的分層／targeted cleanup，不可直接執行完整destroy。

最後一點是目前structure的重要限制：M4與M5共享同一state，destroy scope必須特別審查。

## 21. Freeze前必須真正理解的12件事

1. ECR只儲存image；Docker負責build，Terraform負責repository lifecycle。
2. ECS Cluster是邏輯執行邊界，不是server。
3. Task Definition是版本化workload blueprint。
4. Task是blueprint的一次實際執行，可能隨時被replace。
5. ECS Service維持desired task數並整合ALB health。
6. Fargate `awsvpc`讓每個task取得自己的ENI與IP。
7. ALB listener接收client traffic，target group追蹤task IP與health。
8. SG chain以SG identity而非固定IP控制ALB→Task→RDS。
9. RDS獨立保存Order data，task replacement不應刪除資料。
10. RDS產生secret；ECS execution role在啟動時讀取；Terraform state沒有password value。
11. Actuator回答application能否接受request，ALB以它決定target health。
12. Packet能通必須同時具備DNS、route、SG permission、listener與healthy target，而不是diagram上畫了箭頭就會通。
