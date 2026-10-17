# orbit ci-iam

The CI identity: a GitHub OIDC provider plus one IAM role that workflows assume. No long-lived keys anywhere. This root exists separately from infra-ecs because destroying the shop must never destroy the thing that builds the shop.

What it makes: an OIDC provider trusting `token.actions.githubusercontent.com`, a role whose trust policy only allows this repo's workflows to assume it, and three policies attached to that role:

- ecr: push and pull `orbit/*` images
- ecs: redeploy and describe the orbit services
- tofu: full lifecycle of the stack (apply and destroy), scoped so IAM actions only touch orbit roles

The role ARN goes into the repo secret `AWS_ROLE_ARN`. Nothing account-specific lives in tracked files here: org, repo and bucket name come from gitignored `terraform.tfvars`, and the region and account id are read from whoever runs the apply.

```text
devbox run ci-iam-init      backend init for this root
devbox run ci-iam-validate  check the config
devbox run ci-iam-plan      see what would change
devbox run ci-iam-apply     make it real
devbox run ci-iam-destroy   tear it down
```

Files work like the other roots: `versions.tf` pins the tool and provider, `variables.tf` declares its inputs, `main.tf` holds the resources, `outputs.tf` exposes the role ARN, and anything ending in `.example` is the committable template.
