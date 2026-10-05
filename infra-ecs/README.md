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

## the rest of the infra

- main root: VPC (2 AZ, single NAT), ECR repos per service, ALB with ACM cert on 443
- 10 ECS Fargate services discovered through Service Connect namespace orbit.local
- GitHub Actions with OIDC federation, no stored keys, images tagged by git SHA
- budget alarm at 10 dollars because AWS bills quietly
