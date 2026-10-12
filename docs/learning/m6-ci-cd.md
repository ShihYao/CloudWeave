# M6 — CI/CD

## 範圍

M6 只自動化應用程式交付：測試、打包、容器建置、推送至 ECR、ECS rolling deployment，以及健康狀態驗證。基礎設施生命週期仍由 Terraform 管理。Event-driven services、blue/green、canary 與 multi-Region deployment 均不在此里程碑範圍內。

## Pipeline

Pull Request 會使用 Java 21 執行 `mvn -B clean verify`。Push 至 `main` 時會先執行相同的品質閘門；只有成功後，才透過 GitHub OIDC assume AWS deployment role、建置以 `github.sha` 標記的 image、推送至 immutable ECR repository、註冊只變更 image 的 ECS task-definition revision、更新 service、等待 steady state，最後透過 ALB 呼叫 `/actuator/health`。

測試、Docker build、身分驗證、image push、deployment、穩定化或 smoke test 任一環節失敗，都會使 workflow 失敗。測試失敗時無法進入 deploy job。

## Authentication 與 Authorization

GitHub 不儲存 AWS access key。GitHub 取得 OIDC token，再由 AWS STS 將它交換成短期 role credentials。Trust policy 要求 audience 為 `sts.amazonaws.com`，subject 為 `repo:ShihYao/CloudWeave:ref:refs/heads/main`。

此 role 只能登入 ECR、推送至 Order Service repository、讀取 ECS deployment 狀態、註冊 task definition、更新指定的 Order Service，以及只把該服務的 ECS execution role 傳給 `ecs-tasks.amazonaws.com`。

## GitHub 設定

Repository variables（不是 secrets）：

- `AWS_ROLE_ARN`：Terraform output `github_actions_deploy_role_arn`
- `ALB_BASE_URL`：`http://` 加上 Terraform output `alb_dns_name`

`AWS_REGION`、ECR repository、ECS cluster、ECS service 與 container name 都是非敏感 workflow configuration。selected Region 固定為 `ap-southeast-2`。

## Ownership 與 Rollback

ADR-002 定義 Terraform 與 CI/CD 的責任邊界。Rollback 是將 ECS service 更新至已知正常的舊 task-definition revision；該 revision 使用不可覆寫的 commit SHA image。ECS deployment circuit breaker 維持啟用並自動 rollback。本設計刻意不使用 `latest`。

## 驗證證據

- 本機 build：15 個測試全部通過。
- Terraform validation：成功。
- 已審查 plan：3 add、0 change、0 destroy。
- 已建立資源：GitHub OIDC provider、deployment role、限定範圍的 inline policy。
- M6 Freeze 前仍須記錄完整 GitHub workflow 執行與 failure exercises。

## Failure Exercises

1. CI failure：在 branch/PR 暫時加入失敗測試，確認 deploy 被跳過，再還原測試。
2. OIDC/IAM failure：暫時使用錯誤 role ARN，或移除一項必要權限；觀察 AWS step failure 與 CloudTrail evidence，之後還原已審查的設定。不得放寬 repository/branch trust boundary。

## 已知限制

- desired task 為 1 的 rolling deployment 適合此 learning environment，但不代表 production high availability。
- Smoke test 只驗證健康狀態，不建立 business data。
- GitHub-hosted Actions 目前使用 major-version tags；未來可將 action 固定至完整 commit SHA，以進一步強化 software supply chain。
