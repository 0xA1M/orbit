# orbit infra-ecs

The OpenTofu that stands up and runs the whole shop: one VPC spread over two AZs, ten container services on Fargate discovering each other through Service Connect, and an ALB with my own ACM cert on 443 as the front door.

To use it yourself start at bootstrap/, copy terraform.tfvars.example to terraform.tfvars, put in your own bucket name and apply. Everything else depends on that bucket existing first.

## bootstrap

One time setup that creates the S3 bucket holding OpenTofu state for every other root in this repo.

What it makes: one S3 bucket, versioned (every apply keeps the old state file so a bad apply can be rolled back), encrypted with SSE-S3, and locked down from public access four different ways.

Why it is not in the GitHub Actions pipeline: bootstrap runs exactly once from my machine with an already authenticated AWS CLI. CI does not need to re-run a one time thing, and letting CI touch the state bucket would mean giving the pipeline permissions to destroy state. So CI only handles the real infrastructure roots, not this one.

Files, each has short comments explaining what is going on:

- versions.tf pins OpenTofu and AWS provider versions
- variables.tf region, bucket name, tags
- main.tf provider wiring plus bucket with its guards
- outputs.tf bucket name and ARN
- terraform.tfvars.example values, copy it to terraform.tfvars and fill your own bucket name

After bootstrap is applied, the other roots point their backend block at this bucket using the outputs.

## ecr

Every service gets its own image repository under a shared `orbit/` namespace, so `orbit/frontend`, `orbit/cartservice` and the rest sit side by side and can be scoped as one group by IAM and CI.

Tags are immutable once pushed, so a git SHA tag cannot be overwritten and a deployed SHA always points at the image that was actually built. The two exceptions are `latest*` and `dev-*`: CI repoints `latest` on every build, and local pushes reuse a `dev-` tag, so those have to stay mutable.

Every push is scanned for known CVEs automatically, and repos are encrypted at rest with AES256, the S3-managed keys, so there is no customer KMS key to pay for or rotate.

A lifecycle policy keeps storage from growing forever. An image no one has pulled in 15 days moves to archive storage, which is cheaper but still pullable, and 60 days after it was archived it is expired and deleted.

## the rest of the infra

- main root: VPC (2 AZ, one NAT per AZ), ECR repos per service, ALB with ACM cert on 443
- 10 ECS Fargate services discovered through Service Connect namespace orbit.local
- GitHub Actions with OIDC federation, no stored keys, images tagged by git SHA
- budget alarm at 10 dollars because AWS bills quietly
