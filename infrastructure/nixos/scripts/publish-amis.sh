#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

: "${AWS_REGION:?AWS_REGION must be set}"
: "${AMI_BUCKET:?AMI_BUCKET must be set}"
: "${AMI_SSM_PREFIX:?AMI_SSM_PREFIX must be set}"

echo "Verifying AMI staging bucket ${AMI_BUCKET} exists..."
if ! aws s3api head-bucket --bucket "${AMI_BUCKET}" >/dev/null 2>&1; then
  echo "AMI staging bucket ${AMI_BUCKET} is not accessible. Run Terraform to create it before publishing AMIs." >&2
  exit 1
fi

timestamp="$(date +%Y%m%d%H%M%S)"
build_dir="$(mktemp -d)"
trap 'rm -rf "$build_dir"' EXIT

declare -A targets=(
  ["wireguard"]="wireguard-ami"
  ["nat"]="nat-ami"
  ["reverse-proxy"]="reverse-proxy-ami"
)

find_image() {
  local path="$1"
  find "$path" -maxdepth 1 -type f \( -name '*.vhd' -o -name '*.raw' -o -name '*.img' \) | head -n1
}

for logical in "${!targets[@]}"; do
  package="${targets[$logical]}"
  out_link="${build_dir}/${logical}-result"

  echo "Building ${logical} AMI..."
  nix build "${ROOT_DIR}#${package}" -o "${out_link}"

  image_path="$(find_image "${out_link}")"
  if [[ -z "${image_path}" ]]; then
    echo "failed to locate built image for ${logical}" >&2
    exit 1
  fi

  extension="${image_path##*.}"
  case "${extension}" in
    vhd|VHD) format="vhd" ;;
    raw|img) format="raw" ;;
    *) format="vhd" ;;
  esac

  s3_key="nix-amis/${logical}/${timestamp}/$(basename "${image_path}")"
  echo "Uploading ${image_path} to s3://${AMI_BUCKET}/${s3_key}"
  aws s3 cp "${image_path}" "s3://${AMI_BUCKET}/${s3_key}"

  echo "Importing image into EC2..."
  import_task_id="$(
    aws ec2 import-image \
      --region "${AWS_REGION}" \
      --description "vpn-${logical}-${timestamp}" \
      --disk-containers "Format=${format},UserBucket={S3Bucket=${AMI_BUCKET},S3Key=${s3_key}}" \
      --query 'ImportTaskId' \
      --output text
  )"

  echo "Waiting for import task ${import_task_id} to complete..."
  while true; do
    read -r status ami_id <<<"$(
      aws ec2 describe-import-image-tasks \
        --region "${AWS_REGION}" \
        --import-task-ids "${import_task_id}" \
        --query '[ImportImageTasks[0].Status,ImportImageTasks[0].ImageId]' \
        --output text
    )"

    case "${status}" in
      completed)
        break
        ;;
      deleting|deleted|cancelled|cancelling)
        echo "import task ${import_task_id} ended with status ${status}" >&2
        exit 1
        ;;
      *)
        sleep 30
        ;;
    esac
  done

  if [[ -z "${ami_id}" || "${ami_id}" == "None" ]]; then
    echo "failed to resolve AMI ID for ${logical}" >&2
    exit 1
  fi

  param_name="${AMI_SSM_PREFIX}/${logical}"
  echo "Publishing AMI ID ${ami_id} to SSM parameter ${param_name}"
  aws ssm put-parameter \
    --region "${AWS_REGION}" \
    --name "${param_name}" \
    --type "String" \
    --value "${ami_id}" \
    --overwrite >/dev/null
done

echo "AMI publication completed."
