/*
Internet Client
  │
  │ HTTP :80
  ▼
aws_lb.order
  │
  │ aws_lb_listener.http
  │ 接收HTTP :80
  ▼
aws_lb_target_group.order
  │
  │ healthy Task IP :8080
  ▼
Fargate Task ENI
  │
  ▼
Spring Boot Order Service :8080
*/

resource "aws_lb" "order" {
  name                       = "${local.name_prefix}-order-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.ingress.id]
  subnets                    = values({ for key, subnet in aws_subnet.this : key => subnet.id if local.subnets[key].public })
  enable_deletion_protection = false
  drop_invalid_header_fields = true
  tags                       = local.workload_tags
}

resource "aws_lb_target_group" "order" {
  name                 = "${local.name_prefix}-order-tg"
  port                 = local.container_port
  protocol             = "HTTP"
  target_type          = "ip" # ALB註冊的是Task ENI的IP
  vpc_id               = aws_vpc.main.id
  deregistration_delay = 30
  # 只有回傳HTTP 200的Task才會成為healthy target並接收request
  health_check {
    path                = "/actuator/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30 #每30秒檢查一次
    timeout             = 5  #5秒沒有回應就timeout
    healthy_threshold   = 2  #連續2次成功 → healthy
    unhealthy_threshold = 3  #連續3次失敗 → unhealthy
  }
  tags = local.workload_tags
}

# ALB收到TCP/HTTP port 80 request → Listener處理
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.order.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.order.arn
  }
  tags = local.workload_tags
}
