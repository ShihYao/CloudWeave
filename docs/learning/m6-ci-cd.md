# M6 - CI/CD

## Scope

M6 automates application delivery only: test, package, container build, ECR push, ECS rolling deployment, and health verification. Infrastructure lifecycle remains in Terraform. Event-driven services, blue/green, canary, and multi-Region deployment are outside this milestone.

## Pipeline

Pull requests run Java 21 and `mvn -B clean verify`. A push to `main` runs the same gate and, only after success, assumes the AWS deployment role through GitHub OIDC, builds an image tagged with `github.sha`, pushes it to the immutable ECR repository, registers an image-only ECS task-definition revision, updates the service, waits for steady state, and calls `/actuator/health` through the ALB.

Test, Docker build, authentication, push, deployment, stabilization, or smoke-test failure makes the workflow fail. A failed test cannot reach the deploy job.

## Authentication and authorization

No AWS access key is stored in GitHub. GitHub requests an OIDC token; AWS STS exchanges it for temporary role credentials. The trust policy requires audience `sts.amazonaws.com` and subject `repo:ShihYao/CloudWeave:ref:refs/heads/main`.

The role can authenticate to ECR, push only to the Order Service repository, describe ECS deployment state, register a task definition, update only the Order Service, and pass only its ECS execution role to `ecs-tasks.amazonaws.com`.

## GitHub configuration

Repository variables (not secrets):

- `AWS_ROLE_ARN`: Terraform output `github_actions_deploy_role_arn`
- `ALB_BASE_URL`: `http://` plus Terraform output `alb_dns_name`

`AWS_REGION`, ECR repository, ECS cluster, ECS service, and container name are non-sensitive workflow configuration. The selected Region is always `ap-southeast-2`.

## Ownership and rollback

ADR-002 defines the Terraform/CI boundary. Rollback means updating the ECS service to a known-good prior task-definition revision whose image uses an immutable commit SHA. The ECS deployment circuit breaker remains enabled with rollback. `latest` is intentionally absent.

## Verification evidence

- Local build: 15 tests passed.
- Terraform validation: successful.
- Reviewed plan: 3 add, 0 change, 0 destroy.
- Applied resources: GitHub OIDC provider, deployment role, scoped inline policy.
- End-to-end GitHub workflow run and failure exercises must be recorded before M6 Freeze.

## Failure exercises

1. CI failure: introduce a temporary failing test in a branch/PR and verify that deploy is skipped; restore the test afterward.
2. OIDC/IAM failure: temporarily use an invalid role ARN or remove one required permission, observe the failed AWS step and CloudTrail evidence, then restore the reviewed configuration. Do not weaken the repository/branch trust boundary.

## Known limitations

- Rolling deployment with one desired task is suitable for this learning environment, not a production HA claim.
- Smoke testing verifies health and does not create business data.
- GitHub-hosted action major tags are used; pinning full commit SHAs is a future supply-chain hardening step.
