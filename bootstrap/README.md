# orbit bootstrap

One time root. Creates the S3 bucket that holds OpenTofu state for the other roots, then steps out of the way.

What it makes: one S3 bucket, versioned (every state write keeps the previous version, so a bad apply can be rolled back), encrypted at rest with SSE-S3, and blocked from public access four ways: acls blocked, policies blocked, stray acls ignored, and public buckets restricted.

Why its state is local: this root creates the bucket every other root keeps its state in, so it cannot keep its own state there. It runs with local state on my machine and that file is not committed.

Why it is not in the GitHub Actions pipeline: it runs once, from my machine, with the AWS CLI already authenticated. CI has no reason to re-run a one time setup, and handing a pipeline the rights to touch the state bucket would mean handing it the rights to destroy state.

Files:

- versions.tf pins OpenTofu and the AWS provider
- variables.tf region, bucket name, tags
- main.tf provider plus the bucket with its guards
- outputs.tf bucket name and ARN, for other roots' backend blocks
- terraform.tfvars.example copy it to terraform.tfvars and put your own globally unique bucket name in

Every other root points its backend at this bucket and gives itself a unique key, so no root can clobber another's state.
