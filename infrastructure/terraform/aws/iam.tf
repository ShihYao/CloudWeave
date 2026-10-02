# M3 freezes authentication hygiene, not workload role trust or permission policies.
# ECS task/execution roles belong to M5; CI/CD federation belongs to M6. Creating
# speculative roles here would violate the design freeze and least privilege.
