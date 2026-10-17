# orbit

A playground for exploring AWS container services, mostly ECS and EKS, and learning how to run and operate them for real. The app is Google's microservices-demo, kept as code only (the exact commit is in app/NOTICE), with every piece of infrastructure written by me instead of copied.

Right now the shop runs on AWS: one VPC spread over two AZs, eleven services on ECS Fargate finding each other through Service Connect, an ALB with my own ACM cert as the front door, and images in ECR. DNS lives in Cloudflare.

## layout

```text
app/          the shop code, my Dockerfiles and tweaks, plus the per service notes
bootstrap/    one time root that creates the S3 bucket holding OpenTofu state
infra-ecs/    the OpenTofu that builds and runs the shop on ECS
ci-iam/       the CI identity: GitHub OIDC trust plus the role pipelines assume
```

app/README.md has the per service notes: ports, env vars, what calls what. Each infra root has its own README describing what it builds.

## running it

Everything runs from a devbox shell at the repo root, which brings OpenTofu, the AWS CLI, grpcurl and the Go tooling. Outside devbox you need Docker, git, and AWS credentials on your machine.

Start with bootstrap. It creates the bucket that holds state for the other roots, and since it cannot keep its own state there it runs with local state:

```text
devbox run bootstrap-init      first time only
devbox run bootstrap-plan      see what it would make
devbox run bootstrap-apply     create the bucket
```

After that the other roots point their backends at that bucket and use the shared scripts, which default to the infra-ecs root and take another root as an argument when you need one:

```text
devbox run sts         check who you are on AWS first
devbox run init        hook the backend up
devbox run validate    check the config
devbox run plan        see what would change
devbox run apply       make it real
devbox run destroy     tear it down
devbox run ecr-login   docker login for pushing images
```

The CI identity root has its own scripts, same lifecycle:

```text
devbox run ci-iam-init
devbox run ci-iam-plan
devbox run ci-iam-apply
devbox run ci-iam-destroy
```

Everything is local first: applies run from my machine, with my own credentials.

## the shop

Eleven services: the ten from the demo plus the load generator. `frontend` is the only one that speaks HTTP and the only one the ALB reaches. Everything else talks gRPC behind it, addressed by short names like `productcatalogservice:3550` through Service Connect.

Each service gets its own security group that opens its port only to the services that actually call it, so the network graph mirrors the call graph instead of a flat allow everything inside the VPC.

TLS terminates at the ALB with a cert from ACM for the site hostname, validated with a DNS record in Cloudflare. Inside the VPC everything is plain HTTP: the traffic never leaves the private subnets.
