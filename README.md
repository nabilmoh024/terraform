# Terraform practice: vpc + ec2 modules, split state, dev and prod

A small project for practising Terraform modules on AWS. It implements the workflow
from the diagram: shared modules, one folder per environment and stack, a separate
state file for each stack, and values supplied through `terraform.tfvars`.

The structure follows the [terraform-skill](https://github.com/antonbabenko/terraform-skill)
best practices (composition per environment, modules without tfvars, typed and validated
variables, `for_each` with stable keys, partial backend config, remote state with native locking).

## What you get

```text
terraform-practice/
├── bootstrap/state-backend/      # run once: creates the S3 state buckets (local state)
├── modules/                      # reusable, environment-agnostic code
│   ├── vpc/                      # VPC, public + private subnets, routing, optional NAT
│   │   ├── main.tf  variables.tf  outputs.tf  versions.tf  README.md
│   │   ├── examples/minimal/     # try the module alone: no NAT, no cost while it exists
│   │   └── tests/vpc.tftest.hcl
│   └── ec2/                      # instance, security group, SSM role, IMDSv2, encrypted disk
│       ├── main.tf  variables.tf  outputs.tf  versions.tf  README.md
│       ├── examples/with-vpc/    # try the module alone, paired with the vpc module
│       └── tests/ec2.tftest.hcl
├── environments/                 # one folder per environment, one stack per folder
│   ├── dev/
│   │   ├── backend.hcl           # bucket + region shared by every dev stack
│   │   ├── vpc/   main.tf variables.tf outputs.tf versions.tf backend.tf terraform.tfvars
│   │   └── ec2/   main.tf variables.tf outputs.tf versions.tf backend.tf terraform.tfvars
│   └── prod/
│       ├── backend.hcl
│       ├── vpc/   (same code, different backend key and values)
│       └── ec2/
├── scripts/check-env-parity.sh   # fails if dev and prod code drift or a state key is wrong
└── .github/workflows/validate.yml  # fmt, validate, tests, parity: no AWS credentials needed
```

Each stack has its own state file, so a mistake in one never touches the others:

| Stack | State object |
|---|---|
| dev vpc | `s3://tf-state-dev-<account>/dev/vpc/terraform.tfstate` |
| dev ec2 | `s3://tf-state-dev-<account>/dev/ec2/terraform.tfstate` |
| prod vpc | `s3://tf-state-prod-<account>/prod/vpc/terraform.tfstate` |
| prod ec2 | `s3://tf-state-prod-<account>/prod/ec2/terraform.tfstate` |

Between dev and prod, `main.tf`, `variables.tf`, `outputs.tf` and `versions.tf` are
identical. Only `backend.tf` (the state key) and `terraform.tfvars` (the values) differ.
That is the whole point of the layout, and `scripts/check-env-parity.sh` enforces it.

## Where variables live and how they flow

Follow `vpc_cidr_block` through the dev vpc stack:

| Step | File | What happens |
|---|---|---|
| 1. Assign | `environments/dev/vpc/terraform.tfvars` | `vpc_cidr_block = "10.0.0.0/16"`. The only place real values live. Loaded automatically. |
| 2. Declare | `environments/dev/vpc/variables.tf` | Declares `var.vpc_cidr_block` for the stack (type, description). No default, so a missing value fails loudly. |
| 3. Pass | `environments/dev/vpc/main.tf` | `vpc_cidr_block = var.vpc_cidr_block` inside `module "vpc"`. |
| 4. Receive | `modules/vpc/variables.tf` | The module declares its own input and validates it (must be a real CIDR). |
| 5. Use | `modules/vpc/main.tf` | `cidrsubnet(var.vpc_cidr_block, ...)` builds the subnets. |

Rules to remember:

- **Modules never contain `terraform.tfvars`.** They take inputs and return outputs.
- **Stacks never hardcode environment values in `main.tf`.** They read `var.*`.
- **Backend settings cannot use variables.** So the backend is split in two: settings shared by the whole environment (`bucket`, `region`) live in `environments/<env>/backend.hcl` and are passed with `terraform init -backend-config=../backend.hcl`; the stack-specific `key` stays in that stack's `backend.tf`.
- **Between stacks**, values travel as outputs: `environments/dev/vpc/outputs.tf` exposes `vpc_id` and `private_subnet_ids`, and the ec2 stack reads them with `terraform_remote_state`. The ec2 stack finds the state bucket by the naming rule `tf-state-<environment>-<account id>`, so there is no bucket name to copy into its tfvars.

How Terraform picks a value when the same variable is set in several places (later wins):

1. `default` in `variables.tf`
2. `TF_VAR_name` environment variable
3. `terraform.tfvars`
4. `*.auto.tfvars`
5. `-var-file=...` and `-var="name=value"` on the command line

Secrets (database passwords, tokens) never go in `terraform.tfvars`. Use `TF_VAR_*`
variables from your CI secret store, or let the service generate and store them (RDS
can manage its master password in Secrets Manager).

## Before you start

- Terraform 1.10 or newer (or OpenTofu 1.10+). Check with `terraform version`. Native S3 locking (`use_lockfile`) needs 1.10.
- AWS CLI v2, signed in: `aws sts get-caller-identity` must print your account.
- The [Session Manager plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html) for the AWS CLI, to open a shell on the instance.
- An IAM identity that can create VPC, EC2, IAM role and S3 resources. For practice an admin-level sandbox account is simplest; tighten later.
- Region: everything defaults to `ap-south-1` (Mumbai). To change it, edit `bootstrap/state-backend/variables.tf`, both `backend.hcl` files, and `aws_region` plus `availability_zones` in every `terraform.tfvars` (and the two `examples/`). `grep -r ap-south-1 .` finds them all.
- Run `terraform fmt -recursive` once at the start. The files were written by hand without running Terraform, so this settles any whitespace differences before the CI format check sees them.

**Cost warning.** NAT gateways bill by the hour while they exist, and dev uses 1 while
prod uses 3 (one per zone). They are usually the biggest line item in a small practice
setup. Destroy what you are not using (step 6) and check current AWS pricing.

## Step 0 (optional, free): prove the modules work before touching AWS

```bash
cd modules/vpc && terraform init && terraform test
cd ../ec2      && terraform init && terraform test
```

The tests use mocked providers, so they need no credentials and create nothing. The
code was syntax-checked but not executed when it was written, so this is the first real
check. If something fails here, fix it here: it is far cheaper than finding out during an apply.

## Step 1: create the state buckets (once)

```bash
cd bootstrap/state-backend
terraform init
terraform plan -out=tfplan
terraform apply tfplan
terraform output state_bucket_names
```

This creates `tf-state-dev-<account>` and `tf-state-prod-<account>` with versioning,
encryption, public access blocked, TLS-only access and 90-day expiry of old versions.
This is the one stack that uses local state (a bucket cannot store the state that
creates it). The small `terraform.tfstate` it leaves behind is git-ignored; keep a copy.

## Step 2: put your account ID into the two backend.hcl files

The buckets are named after your account ID, so only `environments/dev/backend.hcl` and
`environments/prod/backend.hcl` need your account ID. Nothing else does.

Bash (Linux, macOS, WSL, Git Bash):

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
sed -i "s/ACCOUNT_ID/$ACCOUNT_ID/g" environments/*/backend.hcl     # macOS: sed -i ''
cat environments/*/backend.hcl
```

PowerShell:

```powershell
$acct = aws sts get-caller-identity --query Account --output text
Get-ChildItem environments -Filter backend.hcl -Recurse | ForEach-Object {
  (Get-Content $_.FullName -Raw).Replace('ACCOUNT_ID', $acct) | Set-Content $_.FullName -NoNewline
}
```

The bucket names must match what `terraform output state_bucket_names` printed in step 1.

## Step 3: deploy dev (vpc first, then ec2)

Order matters because the ec2 stack reads the vpc stack's outputs. Note the
`-backend-config` flag on every `init`: without it Terraform asks you for the bucket.

```bash
cd environments/dev/vpc
terraform init -backend-config=../backend.hcl
terraform fmt -check
terraform validate
terraform plan -out=tfplan     # read it: roughly 19 resources (vpc, 4 subnets, routes, 1 NAT)
terraform apply tfplan

cd ../ec2
terraform init -backend-config=../backend.hcl
terraform plan -out=tfplan     # roughly 6 resources (instance, security group, SSM role)
terraform apply tfplan
```

Always apply the saved `tfplan` you just reviewed. Applying a different plan than the
one you read is how surprises reach production.

After the first `init` in each folder, commit the `.terraform.lock.hcl` it creates so
everyone uses the same provider build. If you work on more than one OS, record all
platforms once: `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=windows_amd64`.

## Step 4: check it works

```bash
terraform output                                   # in environments/dev/ec2
aws ssm start-session --target $(terraform output -raw instance_id) --region ap-south-1
```

Give the instance a few minutes to register with Session Manager after it boots. Inside
the shell, prove the private subnet reaches the internet through the NAT gateway:

```bash
curl -sI https://aws.amazon.com | head -1
```

There is no SSH key and no open inbound port. Access is through Session Manager only.

## Step 5: deploy prod

Same commands, different folder, and compare the plan with dev before applying:

```bash
cd environments/prod/vpc && terraform init -backend-config=../backend.hcl && terraform plan -out=tfplan && terraform apply tfplan
cd ../ec2               && terraform init -backend-config=../backend.hcl && terraform plan -out=tfplan && terraform apply tfplan
```

You should see three AZs, three NAT gateways, `t3.small` and a 30 GiB disk. Same code, different tfvars.

## Step 6: clean up (reverse order)

Run `terraform plan -destroy` first and read every line before confirming. Destroy
removes real infrastructure.

```bash
cd environments/prod/ec2 && terraform plan -destroy -out=destroy.tfplan && terraform apply destroy.tfplan
cd ../vpc                && terraform plan -destroy -out=destroy.tfplan && terraform apply destroy.tfplan
cd ../../dev/ec2         && terraform plan -destroy -out=destroy.tfplan && terraform apply destroy.tfplan
cd ../vpc                && terraform plan -destroy -out=destroy.tfplan && terraform apply destroy.tfplan
```

Destroy ec2 before vpc, the opposite of deploying. The state buckets have
`prevent_destroy` on purpose. They cost almost nothing, so leaving them is fine. To
remove them, empty each bucket including old versions, delete the `prevent_destroy`
line in `bootstrap/state-backend/main.tf`, then run `terraform destroy` there.

## Keeping dev and prod in sync

Every environment repeats the same stacks, which is easy to read but easy to let drift:
someone fixes `main.tf` in dev and forgets prod. Three habits prevent it.

- **Change shared code in dev, then copy it.** For example: `cp environments/dev/vpc/main.tf environments/prod/vpc/main.tf`. Only `backend.tf` and `terraform.tfvars` are ever different.
- **Run the parity check** before committing: `bash scripts/check-env-parity.sh`. It fails if shared files differ, if a backend key is not `<environment>/<stack>/terraform.tfstate`, or if a tfvars file says the wrong `environment`. That last mistake is the dangerous one: the prod folder would read dev's vpc state.
- **Let CI run it** (`.github/workflows/validate.yml`) so a drifted pull request cannot merge unnoticed.

If you want prod to differ in structure (for example two app servers), that is a
deliberate change. Make it in both environments with a variable that defaults to
today's behaviour, then set the new value only in prod's tfvars. Differences belong in
tfvars, not in copies of the code.

## Try a module on its own

Each module ships an example you can apply without the environment machinery. It is the
fastest way to experiment, and the same folders are what you would use to test a module
change before rolling it into dev.

```bash
cd modules/vpc/examples/minimal && terraform init && terraform apply     # no NAT, no hourly cost
terraform destroy
cd ../../../ec2/examples/with-vpc && terraform init && terraform apply   # one NAT gateway: destroy afterwards
terraform destroy
```

These use local state, which is fine for a throwaway experiment.

## Practice exercises

1. **Change a value.** Set `instance_type = "t3.small"` in `environments/dev/ec2/terraform.tfvars` and read the plan. Which resource changes and how?
2. **Stable keys.** Add `"ap-south-1c"` to dev `availability_zones` and plan. Only the new zone's resources appear, because subnets are keyed by zone name. Now imagine this had used `count` and think about what would have shifted.
3. **Precedence.** Run `terraform plan -var="instance_type=t3.medium"`, then `TF_VAR_instance_type=t3.large terraform plan`. Which wins over the tfvars file, and why?
4. **Validation.** Set `environment = "qa"` and run `terraform validate` or `plan`. Read the error message you wrote.
5. **Open a port.** Uncomment the `ingress_rules` example in dev ec2 `terraform.tfvars` and apply. Check the security group in the console.
6. **Turn off NAT.** Set `enable_nat_gateway = false` in dev vpc. Plan, then think about what stops working for the instance (including Session Manager).
7. **Run the module tests.** `cd modules/vpc && terraform init && terraform test`, then the same in `modules/ec2`. Break a module on purpose and watch a test fail.
8. **Break parity on purpose.** Add a comment to `environments/prod/vpc/main.tf` and run `bash scripts/check-env-parity.sh`. Then set `environment = "dev"` in a prod tfvars file and run it again. Read both failures.
9. **Add rds.** Copy the ec2 pattern: `modules/rds`, then `environments/dev/rds` reading the vpc state (subnets) and the ec2 state (`security_group_id` to allow inbound from the app). Let RDS manage its master password in Secrets Manager rather than putting one in tfvars. Add the new stack to both environments and let the parity check cover it.

## Best practices used (from terraform-skill) and why

| Practice | Where |
|---|---|
| Separate environments from reusable modules | `environments/` vs `modules/` |
| `terraform.tfvars` and `backend.tf` only at the environment level, never in modules | every stack folder |
| Backend settings passed as a backend file, not hardcoded per stack | `environments/<env>/backend.hcl` |
| Standard file set: `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `README.md` | every module and stack |
| `examples/` as documentation and a place to test a module | `modules/*/examples/` |
| Variables: description, type, default, nullable, validation | all `variables.tf` |
| Context-specific names (`vpc_cidr_block`, not `cidr`) | variables |
| `for_each` with stable keys instead of `count` for collections | subnets, routes, NAT gateways, rules |
| `this` only for single resources; descriptive names for several of a kind | `aws_vpc.this`, `aws_subnet.public` |
| Smaller scopes: one state per stack, smaller blast radius | `environments/<env>/<stack>` |
| Remote state with encryption, versioning and native locking | `bootstrap/` and `backend.tf` |
| Outputs have descriptions and expose a stable subset | all `outputs.tf` |
| Secure defaults: IMDSv2, encrypted disk, no SSH, default SG emptied | `modules/ec2`, `modules/vpc` |
| Provider and Terraform versions pinned, lock file committed | `versions.tf`, `.terraform.lock.hcl` |
| Native tests with mocked providers, including rejection cases | `modules/*/tests/` |
| CI validates with no credentials; deploys are a separate, protected step | `.github/workflows/validate.yml` |

One deliberate deviation to know about: the skill advises using `terraform_remote_state`
sparingly, only at real team or lifecycle boundaries, and preferring module outputs or
cloud data sources when one team controls both stacks. This project uses it because it
mirrors your split-state diagram and teaches the pattern. The lighter alternative is to
replace it in `environments/*/ec2/main.tf` with `data "aws_vpc"` and `data "aws_subnets"`
filtered by the `Name` and `Tier` tags the vpc module already sets. That removes the
dependency on the vpc state file entirely.

## Practice shortcuts versus real production

| Here (practice) | In production |
|---|---|
| dev and prod in one AWS account | One account per environment, each with its own deploy role, so prod access is separate |
| State encrypted with S3-managed keys (`AES256`) | A customer-managed KMS key, with IAM scoped to `prod/*` and access logging on the bucket |
| You run `apply` from your laptop | CI applies a reviewed plan artifact using OIDC, with manual approval for prod |
| `terraform_remote_state` between your own stacks | Data sources or module outputs, unless another team owns the producer |
| All outbound traffic allowed from the instance | Restrict egress (for example HTTPS only) or use VPC endpoints |

## Quality checks to run before every commit

```bash
terraform fmt -recursive                     # formatting
bash scripts/check-env-parity.sh             # dev and prod in sync
terraform validate                           # after init, in each stack and module
tflint --recursive                           # lint (install tflint separately)
trivy config .                               # security scan (install trivy separately)
(cd modules/vpc && terraform test)           # unit tests
(cd modules/ec2 && terraform test)
```

`.github/workflows/validate.yml` runs the format check, the parity check, validation of
every module, example and stack, and the module tests on each pull request. It needs no
AWS credentials. A natural next step is a second workflow that plans every changed stack,
applies dev on merge, and applies prod after a manual approval, authenticating with OIDC
instead of stored keys.

## Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `init` asks you to enter a bucket name | You forgot `-backend-config=../backend.hcl`. |
| `NoSuchBucket` during `init` | `ACCOUNT_ID` was not replaced in `backend.hcl` (step 2), or step 1 did not finish. |
| `Backend configuration changed` | You edited `backend.tf` or `backend.hcl`. Run `terraform init -reconfigure -backend-config=../backend.hcl`. |
| ec2 plan fails on `outputs.vpc_id` or an unsupported attribute | The vpc stack for that environment is not applied yet, or its state key differs. |
| ec2 plan cannot read the vpc state bucket | The bucket name is derived as `tf-state-<environment>-<account id>`. Check `environment` in tfvars and that you are signed in to the same account that ran step 1. |
| `AccessDenied` on the state bucket | The identity needs `s3:ListBucket`, `s3:GetObject`, `s3:PutObject` and `s3:DeleteObject` on the bucket (locking writes and removes a `.tflock` object). |
| Stuck lock (`Error acquiring the state lock`) | Another run is active, or one crashed. Confirm nothing is running, then `terraform force-unlock <id>`. |
| `check-env-parity.sh` fails | Read the message: it names the exact file. Fix the file, or copy it from dev. |
| Instance never shows in Session Manager | NAT is disabled or not yet routed, the role was not created, or it has not finished booting. |
| Plan wants to replace the instance after an AMI release | Not expected: `ignore_changes = [ami]` is set. To roll to a new AMI on purpose, use `terraform apply -replace='module.app.aws_instance.this'`. |
