# ecr module: one repo per service under orbit/, immutable tags except latest/dev, scan on push, archive-then-expire lifecycle

# for_each over a set, so adding or dropping a service only touches that one repo
resource "aws_ecr_repository" "infra_ecs_orbit_repo" {
  for_each = var.service_list

  # orbit/ namespace lets IAM and CI scope with one orbit/* rule,
  # immutable stops a pushed git SHA from being silently overwritten,
  # AES256 is the free S3-managed key, KMS would cost a key per repo
  name                 = "orbit/${each.key}"
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"
  encryption_configuration {
    encryption_type = "AES256"
  }

  # latest* stays mutable, CI moves it on every build
  image_tag_mutability_exclusion_filter {
    filter      = "latest*"
    filter_type = "WILDCARD"
  }

  # dev-* stays mutable, local pushes reuse the tag
  image_tag_mutability_exclusion_filter {
    filter      = "dev-*"
    filter_type = "WILDCARD"
  }

  # findings show up with the image, no extra trigger needed
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.name_prefix}-${each.key}-repo"
  }
}

# same set as the repos, so a policy never points at a repo that is gone
resource "aws_ecr_lifecycle_policy" "infra_ecs_orbit_repo_policy" {
  for_each   = var.service_list
  repository = aws_ecr_repository.infra_ecs_orbit_repo[each.key].name

  # archive first (cheap but still pullable), expire only 60 days later,
  # so a rollback still has a window before the image is really gone
  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Archive images not pulled in 15 days",
      "selection": {
        "tagStatus": "any",
        "countType": "sinceImagePulled",
        "countUnit": "days",
        "countNumber": 15
      },
      "action": {
        "type": "transition",
        "targetStorageClass": "archive"
      }
    },
    {
      "rulePriority": 2,
      "description": "Delete images archived for more than 60 days",
      "selection": {
        "tagStatus": "any",
        "storageClass": "archive",
        "countType": "sinceImageTransitioned",
        "countUnit": "days",
        "countNumber": 90
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}
