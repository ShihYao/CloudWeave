# ADR-002: Terraform and CI/CD ECS ownership

- Status: Accepted
- Date: 2026-10-05

## Context

M5 Terraform manages the ECS service and a baseline task definition. M6 must deploy an immutable image tagged with the Git commit SHA without running `terraform apply` for every application release. If both systems manage the service task-definition pointer, a later Terraform apply can roll back a successful CI/CD deployment.

## Decision

Terraform owns ECR, ECS infrastructure, service configuration, IAM, networking, and the baseline task definition. GitHub Actions copies the task definition currently used by the service, changes only the Order Service image, registers a new revision, and updates the service pointer. Terraform ignores drift only for `aws_ecs_service.order.task_definition`.

Runtime configuration changes such as CPU, memory, ports, secrets, or roles must first be introduced through Terraform as a new baseline. CI/CD is not an infrastructure pipeline.

## Consequences

- Application releases remain traceable from commit SHA to ECR image and ECS revision.
- Terraform no longer rolls the service back to an older application revision.
- Operators must deliberately establish a new Terraform baseline when task runtime configuration changes.
- Rollback selects a known-good immutable task-definition revision; `latest` is not used.
