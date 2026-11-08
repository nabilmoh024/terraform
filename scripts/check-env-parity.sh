#!/usr/bin/env bash
# Guards the multi-environment layout. Run from anywhere:  bash scripts/check-env-parity.sh
#
# Every environment repeats the same stacks, so three things can silently go wrong:
#   1. Shared code drifts: someone fixes main.tf in dev and forgets prod.
#   2. A backend key points at the wrong place, so two stacks share one state file.
#   3. A tfvars file says environment = "dev" inside the prod folder, so prod would
#      read dev's vpc state.
# Only backend.tf (the key) and terraform.tfvars (the values) may differ between environments.
set -euo pipefail
cd "$(dirname "$0")/.."

baseline=dev
shared_files=(main.tf variables.tf outputs.tf versions.tf)
status=0

fail() {
  echo "FAIL: $*"
  status=1
}

for env_dir in environments/*/; do
  env=$(basename "$env_dir")

  [ -f "environments/$env/backend.hcl" ] || fail "environments/$env/backend.hcl is missing"

  for stack_dir in "$env_dir"*/; do
    stack=$(basename "$stack_dir")

    # 2. The state key must be exactly <environment>/<stack>/terraform.tfstate
    if ! grep -Eq "^[[:space:]]*key[[:space:]]*=[[:space:]]*\"$env/$stack/terraform.tfstate\"" "${stack_dir}backend.tf"; then
      fail "${stack_dir}backend.tf: key must be \"$env/$stack/terraform.tfstate\""
    fi

    # 3. The environment value must match the folder it lives in
    if ! grep -Eq "^environment[[:space:]]*=[[:space:]]*\"$env\"" "${stack_dir}terraform.tfvars"; then
      fail "${stack_dir}terraform.tfvars: environment must be \"$env\""
    fi

    # 1. Shared code must be identical to the baseline environment
    [ "$env" = "$baseline" ] && continue
    for file in "${shared_files[@]}"; do
      reference="environments/$baseline/$stack/$file"
      if [ ! -f "$reference" ]; then
        fail "$reference does not exist, but $stack_dir$file does"
      elif ! diff -q "$reference" "$stack_dir$file" > /dev/null; then
        fail "$stack_dir$file differs from $reference (run: diff $reference $stack_dir$file)"
      fi
    done
  done
done

if [ "$status" -eq 0 ]; then
  echo "OK: environments are in sync (shared code identical, keys and environment values correct)"
fi
exit "$status"
