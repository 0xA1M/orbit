# orbit infra-ecs

The OpenTofu that stands up and runs the whole shop: one VPC spread over two AZs, eleven services on Fargate discovering each other through Service Connect, and an ALB with my own ACM cert on 443 as the front door.

State bucket comes first: it is created once by the bootstrap root at `../bootstrap`, which has its own README. This root only points its backend at that bucket and gives itself a unique key.

## ecr

Every service gets its own image repository under a shared `orbit/` namespace, so `orbit/frontend`, `orbit/cartservice` and the rest sit side by side and can be scoped as one group by IAM and CI.

Tags are immutable once pushed, so a git SHA tag cannot be overwritten and a deployed SHA always points at the image that was actually built. The two exceptions are `latest*` and `dev-*`: CI repoints `latest` on every build, and local pushes reuse a `dev-` tag, so those have to stay mutable.

Every push is scanned for known CVEs automatically, and repos are encrypted at rest with AES256, the S3-managed keys, so there is no customer KMS key to pay for or rotate.

A lifecycle policy keeps storage from growing forever. An image no one has pulled in 15 days moves to archive storage, which is cheaper but still pullable, and 90 days after it was archived it is expired and deleted.

## acm

One ACM certificate for the single hostname `orbit.example.com`. This is what the ALB serves on 443. Nothing wider is requested: no apex, no wildcard, so one hostname and one validation record.

Validation is DNS, but the zone lives in Cloudflare rather than Route53, so a Cloudflare provider block creates the validation CNAME from the cert's own validation options. A `aws_acm_certificate_validation` resource then waits on that record, so the cert reaches ISSUED inside the same apply instead of sitting PENDING for a human to paste a CNAME.

Outputs:

- certificate_arn, the ARN of the issued cert, sourced from the validation so the ALB listener implicitly waits for ISSUED instead of attaching a PENDING cert
- domain_validation, the record set ACM asked for, kept around for inspection

## dns

Two Cloudflare records, both unproxied (gray cloud: the ALB terminates TLS, so Cloudflare must not intercept):

- the validation CNAME from the ACM module, which proves I own the hostname
- the site CNAME, `orbit` pointed at the ALB's DNS name, which is what browsers actually resolve

Both are created by OpenTofu from the same hostname variable, so there is one hostname to change and nowhere for a record to drift from it.

## alb

The public front door. Internet-facing ALB across both public subnets, with its own security group letting 80 and 443 in from anywhere. Port 443 serves the ACM cert and forwards everything to the frontend target group. Port 80 just bounces everything to 443 with a permanent redirect.

Targets register by IP, not instance id, because Fargate tasks are ENIs with addresses, not EC2 boxes. Health checks hit `/_healthz` and want a 200 back. Deletion protection stays off so a teardown is never blocked by it.

## ecs services

One cluster, one Service Connect namespace, eleven services. Each service is the same shape: a log group, its own execution role, a task definition, and the service itself. Anything that differs per service lives in `services.tf` at the root: image, port, env vars, cpu and memory, and who calls it.

The frontend is the only service wired to the ALB. Backends render no load balancer block at all.

Security groups are built from the caller lists, one group per service, one ingress rule per caller edge. `productcatalogservice` for example accepts traffic only from the frontend, checkout and recommendation. The frontend accepts only the ALB. Nothing is reachable from another service that does not actually call it.

Deploys use the circuit breaker with rollback, so a task that cannot start stops its own deployment and reverts instead of crash looping forever.

## how it fits together

Traffic comes in from the internet to an ALB sitting in the public subnets. The ALB terminates TLS with the ACM cert and forwards plain HTTP to the frontend service on 8080. Everything else talks behind it over Service Connect short names like `productcatalogservice:3550`, inside the private subnets. Outbound stuff like ECR image pulls and log shipping goes out through one NAT per AZ.

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
  variables.tf      region, site hostname, cloudflare zone id
  versions.tf       tool pins (AWS + Cloudflare) plus the S3 backend block
  backend.tfvars    gitignored, holds the state bucket name
  terraform.tfvars  gitignored, holds the site hostname and other real values
```

Anything ending in `.example` is the committable template. Copy it, fill your own values, the real file stays on your machine.

## running it

Needs devbox plus an authenticated AWS CLI on your machine. The devbox shell gives you OpenTofu, the AWS CLI, grpcurl and friends. Everything runs locally, with my own credentials.

```text
devbox run infra-ecs-init       # backend init for this root
devbox run infra-ecs-validate   # check the config
devbox run infra-ecs-plan       # what would change
devbox run infra-ecs-apply      # make it real
devbox run infra-ecs-destroy    # tear it down
devbox run sts                  # who am I authenticated as
devbox run ecr-login            # docker login for pushing images
```

Every root has its own set with the same verbs, so a new root just adds five more lines. The backend file lives next to each root (`infra-ecs/backend.tfvars`).

First time from scratch: apply the bootstrap root, then `devbox run infra-ecs-init`, then plan and apply this root.
