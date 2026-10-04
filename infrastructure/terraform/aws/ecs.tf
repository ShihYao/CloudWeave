/*
ECR Repository
  ↓ repository_url
ECS Task Definition
  ↓ 描述執行規格
ECS Service
  ↓ desired_count = 1
Fargate Task拉取image
  ↓
Order Service Container

第一次部署的實際流程:

Terraform建立ECR repository
→ 本機docker build
→ Docker登入ECR
→ docker tag
→ docker push
→ Terraform建立Task Definition與ECS Service
→ Fargate從ECR pull image

Task Definition
  = 一個Task應該怎麼執行

ECS Service
  = 應該持續執行幾個Task、放在哪裡、如何接上ALB，
    Task失敗時是否重新建立

Service啟動後的完整流程
Terraform建立ECS Service
→ Service讀取Task Definition revision
→ Fargate在public-a或public-b建立Task
→ Task取得ENI、private IP與public IPv4
→ Execution Role拉ECR image
→ Execution Role取得RDS secret
→ Container啟動Spring Boot
→ Flyway連線RDS並建立／驗證schema
→ ECS將Task private IP:8080註冊到Target Group
→ ALB呼叫/actuator/health
→ Health check成功
→ Target狀態變成healthy
→ ALB開始轉送client requests

Task失敗時
Container停止
→ essential container停止
→ Task停止
→ Service發現running count = 0
→ Service啟動replacement Task
→ 新Task取得新的ENI與IP
→ 新IP註冊到Target Group
→ health check成功後接收traffic
*/

resource "aws_ecs_cluster" "order" {
  name = "${local.name_prefix}-order"
  setting {
    name  = "containerInsights"
    value = "disabled"
  }
  tags = local.workload_tags
}
resource "aws_cloudwatch_log_group" "order_service" {
  name              = "/ecs/${local.name_prefix}-order-service"
  retention_in_days = 7
  tags              = local.workload_tags
}

/* aws_ecs_task_definition.order_service 定義一個0.5 vCPU、1 GiB、
Linux x86_64的Fargate workload藍圖，告訴ECS要從哪個ECR image
啟動Order Service、開放8080、如何取得RDS設定與secret、
如何送CloudWatch Logs，以及停止時應等待多久。
*/
resource "aws_ecs_task_definition" "order_service" {
  # (family) cloudweave-learning-order-service : (revision) 1
  family = "${local.name_prefix}-order-service"
  # Fargate: AWS負責底層運算環境
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  # 每個Fargate Task配置：
  cpu                = "512"  # 512 CPU units = 0.5 vCPU
  memory             = "1024" # 1024 MiB = 1 GiB
  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }
  # 目前只有一個container
  container_definitions = jsonencode([{
    name      = local.container_name
    image     = "${aws_ecr_repository.order_service.repository_url}:${var.image_tag}"
    essential = true
    # local.container_port = containerPort = hostPort = 8080
    portMappings = [{ name = "http", containerPort = local.container_port, hostPort = local.container_port, protocol = "tcp", appProtocol = "http" }]
    # 一般環境變數: DB連線資訊，Spring Boot在application.properties中讀取
    environment = [{ name = "DB_URL", value = "jdbc:postgresql://${aws_db_instance.order.address}:${aws_db_instance.order.port}/${local.database_name}" }]
    # Secret環境變數
    # ECS runtime
    #  → 使用Execution Role
    #  → Secrets Manager GetSecretValue
    #  → 擷取username/password
    #  → 注入container environment
    #  → Spring Boot讀取DB_USERNAME與DB_PASSWORD
    secrets = [
      { name = "DB_USERNAME", valueFrom = "${aws_db_instance.order.master_user_secret[0].secret_arn}:username::" },
      { name = "DB_PASSWORD", valueFrom = "${aws_db_instance.order.master_user_secret[0].secret_arn}:password::" }
    ]
    logConfiguration = { logDriver = "awslogs", options = { awslogs-group = aws_cloudwatch_log_group.order_service.name, awslogs-region = var.aws_region, awslogs-stream-prefix = "ecs" } }
    # 當ECS停止Task時：
    # ECS先送SIGTERM
    # → 最多等待60秒
    # → application仍未停止才送SIGKILL
    stopTimeout = 60
  }])
  tags = local.workload_tags
}

# 把Task Definition、Fargate運算、網路、Security Group和ALB Target Group組合起來，並持續維持指定數量的健康Tasks
resource "aws_ecs_service" "order" {
  name            = "${local.name_prefix}-order"
  cluster         = aws_ecs_cluster.order.id
  task_definition = aws_ecs_task_definition.order_service.arn
  # 持續存在一個running Task，若是 Production 通常至少：desired_count >= 2，並讓Tasks分散在兩個AZ
  desired_count    = 1
  launch_type      = "FARGATE"
  platform_version = "LATEST"
  # 新Task啟動後，ECS在前120秒暫時忽略ALB health check失敗
  health_check_grace_period_seconds = 120
  wait_for_steady_state             = true
  # 提供deployment失敗保護
  /*
  新的Task Definition revision
  → ECS嘗試啟動新Tasks
  → 新Tasks持續無法穩定
  → Circuit Breaker判定deployment失敗
  → rollback到上一個可用deployment
  */
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
  network_configuration {
    # 目前只有一個Task，所以它只會落在其中一個subnet／AZ
    subnets = values({ for key, subnet in aws_subnet.this : key => subnet.id if local.subnets[key].public })
    # Task ENI會套用Application SG，只允許：
    # ALB Ingress SG
    # → TCP 8080
    # → Application SG
    security_groups  = [aws_security_group.application.id]
    assign_public_ip = true
  }
  # Load Balancer Integration: Service啟動的每一個Task，都要把其中的order-service:8080註冊到指定Target Group
  /*
  Service啟動Task
  → Task取得ENI private IP，例如10.20.0.25
  → ECS把10.20.0.25:8080註冊到Target Group
  → ALB對/actuator/health進行health check
  → Healthy後開始轉送client requests
    */
  load_balancer {
    target_group_arn = aws_lb_target_group.order.arn
    container_name   = local.container_name
    container_port   = local.container_port
  }
  depends_on = [aws_lb_listener.http, aws_iam_role_policy.ecs_task_execution]
  tags       = local.workload_tags
}
