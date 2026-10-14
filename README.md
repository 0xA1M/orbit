# orbit

Trying to learn how to actually run apps on Kubernetes day to day. This is my playground for that.

The app is Google's microservices-demo. Details on which commit are in app/NOTICE. I kept the code and I'm doing all the infra myself.

End goal is simple. Get the shop running on EKS behind Envoy Gateway, deployed with GitOps, TLS done by me with cert-manager, live at https://orbit.example.com for testing.

## layout

```text
app/               the shop code, sanitized, my Dockerfiles and tweaks
infra-ecs/         OpenTofu for the ECS version of the shop

```

app/README.md has the per-service notes: ports, env vars, what calls what.

## running it

Everything runs from a devbox shell at the repo root. That gives you OpenTofu, the AWS CLI, grpcurl, Go tooling and the rest. Outside of devbox you need Docker, git, and an AWS account with credentials configured.

Start with the infra-ecs/README.md, it has the full flow. Short version:

```text
devbox run sts        # check who you are on AWS first
devbox run init       # hook the backend up
devbox run plan       # see what would change
devbox run apply      # make it real
devbox run destroy    # tear it down, I do this after every session
```

Scripts default to the infra-ecs root. Everything is local-first: bootstrap and applies run from my machine with my own AWS credentials.
