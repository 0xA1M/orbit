# orbit infra-ecs

The OpenTofu that stands up and runs the whole shop: one VPC spread over two AZs, ten container services on Fargate discovering each other through Service Connect, and an ALB with my own ACM cert on 443 as the front door.

State bucket comes first: it is created once by the bootstrap root at `../bootstrap`, which has its own README. This root only points its backend at that bucket and gives itself a unique key.

## ecr

Every service gets its own image repository under a shared `orbit/` namespace, so `orbit/frontend`, `orbit/cartservice` and the rest sit side by side and can be scoped as one group by IAM and CI.

Tags are immutable once pushed, so a git SHA tag cannot be overwritten and a deployed SHA always points at the image that was actually built. The two exceptions are `latest*` and `dev-*`: CI repoints `latest` on every build, and local pushes reuse a `dev-` tag, so those have to stay mutable.

Every push is scanned for known CVEs automatically, and repos are encrypted at rest with AES256, the S3-managed keys, so there is no customer KMS key to pay for or rotate.

A lifecycle policy keeps storage from growing forever. An image no one has pulled in 15 days moves to archive storage, which is cheaper but still pullable, and 60 days after it was archived it is expired and deleted.

## acm

One ACM certificate for the single hostname `orbit.example.com`. This is what the ALB serves on 443. Nothing wider is requested: no apex, no wildcard, so one hostname and one validation record.

Validation is DNS, but the zone lives in Cloudflare rather than Route53, so OpenTofu cannot create the validation record itself. There is deliberately no `aws_acm_certificate_validation` resource. That resource is a waiter: it would sit there for up to 75 minutes waiting on a record only a human can create, then fail. Instead the module hands back the validation record and the certificate stays PENDING until I add the CNAME in Cloudflare by hand. Once ACM sees it the cert goes ISSUED and the ALB can attach it.

Outputs:

- certificate_arn, the ARN of the issued cert
- domain_validation, the record name and value to paste into Cloudflare

## alb

The public front door. Internet-facing ALB across both public subnets, with its own security group letting 80 and 443 in from anywhere. Port 443 serves the ACM cert and forwards everything to the frontend target group. Port 80 just bounces everything to 443 with a permanent redirect.

Targets register by IP, not instance id, because Fargate tasks are ENIs with addresses, not EC2 boxes. Health checks hit `/_healthz` and want a 200 back. Deletion protection stays off on purpose since the whole stack gets torn down after sessions.

## how it fits together

Traffic comes in from the internet to an ALB sitting in the public subnets. The ALB terminates TLS with the ACM cert and forwards plain HTTP to the frontend service on 8080. Everything else talks behind it over Service Connect DNS names like `productcatalogservice:3550`, inside the private subnets. Outbound stuff like ECR image pulls and log shipping goes out through one NAT per AZ.

```text
internet
   |
Cloudflare DNS (gray, records only)
   |  A -> ALB
   v
ALB :443 (ACM cert, orbit subdomain)
   |  forward -> frontend :8080
   v
ECS services, private subnets
  frontend -> catalog 3550, checkout 5050, currency 7000,
              cart 7070, recommendation 8081, shipping 50051, ad 9555
  checkout -> shipping, catalog, cart, currency, email 8082, payment 50052
```

## layout

```text
infra-ecs/
  modules/
    network/        VPC, subnets, IGW, NATs, route tables
    ecr/            one image repo per service plus lifecycle policy
    acm/            the TLS cert for the site hostname
    alb/            the front door: public ALB, target group, 443 listener
    ecs-service/    one service: log group, execution role, task def, service
  services.tf       per service wiring: image, port, env, sizing, callers
  ecs_sgs.tf        one identity SG per service plus the caller graph rules
  main.tf           root wiring, instantiates the modules
  variables.tf      region and site hostname
  versions.tf       tool pins plus the S3 backend block
  backend.tfvars    state bucket name, never committed
  terraform.tfvars  site hostname and any real values, never committed
```

Anything ending in `.example` is the committable template. Copy it, fill your own values, the real file stays on your machine.

## running it

Needs devbox plus an authenticated AWS CLI on your machine. The devbox shell gives you OpenTofu, the AWS CLI, grpcurl and friends. Nothing here runs in CI yet.

```text
devbox run init                # backend init for infra-ecs
devbox run validate            # check the config
devbox run plan                # what would change
devbox run apply               # make it real
devbox run destroy              # tear it down when the session ends
devbox run sts                  # who am I authenticated as
devbox run ecr-login            # docker login for pushing images
```

Every script takes an optional root directory as its first argument and defaults to `infra-ecs`, so `devbox run plan -- some-other-root` targets that root instead. Bootstrap is the exception: it has no backend, so run it from `bootstrap/` at the repo root directly.

First time from scratch: apply the bootstrap root, then `devbox run init`, then plan and apply this root.
