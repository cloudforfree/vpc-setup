# VPC lab: Terraform + GitHub Actions

Public subnet (10.0.1.0/24, IGW route) and private subnet (10.0.2.0/24, local route only),
one EC2 instance in each, deployed and destroyed from GitHub Actions.

## One-time setup (run locally with admin credentials)

### 1. State bucket (remote state is required, runners are ephemeral)
```bash
BUCKET=vpc-setup-tfstate-$(aws sts get-caller-identity --query Account --output text)-vpc-lab
aws s3api create-bucket --bucket $BUCKET --region us-east-1
aws s3api put-bucket-versioning --bucket $BUCKET --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $BUCKET \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```
(Outside us-east-1, add `--create-bucket-configuration LocationConstraint=<region>`.)

### 2. GitHub OIDC provider (skip if it already exists in the account)
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list "6938fd4d98bab03faadb97b34396831e3780aea1"
```

### 3. IAM role the workflows assume
Replace ACCOUNT_ID, GH_ORG and REPO, then save as trust.json:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {"Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"},
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {"token.actions.githubusercontent.com:aud": "sts.amazonaws.com"},
      "StringLike": {"token.actions.githubusercontent.com:sub": "repo:GH_ORG/REPO:*"}
    }
  }]
}
```
```bash
aws iam create-role --role-name gha-vpc-lab --assume-role-policy-document file://trust.json
aws iam attach-role-policy --role-name gha-vpc-lab --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
aws iam attach-role-policy --role-name gha-vpc-lab --policy-arn arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess
```
Also give the role read/write on your state bucket (s3:GetObject, PutObject, DeleteObject, ListBucket)
via an inline policy. EC2FullAccess is fine for a lab; tighten it for anything real.

### 4. GitHub repo settings
Secrets: `AWS_ROLE_ARN` = the role ARN.

Variables:
| Name | Example |
|---|---|
| `AWS_REGION` | `us-east-1` |
| `TF_STATE_BUCKET` | the bucket from step 1 |
| `ALLOWED_SSH_CIDR` | `203.0.113.10/32` (your IP) |
| `SSH_PUBLIC_KEY` | contents of your `.pub` file |

Create an environment named `production` (Settings > Environments). Add required reviewers
if you want a manual approval before apply/destroy.

## Use it
- Open a PR touching `terraform/**`: runs fmt, validate and plan.
- Merge to `main`: runs plan, then apply.
- Actions tab > "Terraform destroy" > Run workflow > type `destroy`.

After apply, the job log prints the SSH commands. Then follow the test steps from the CLI lab
(ping, ssh hop, curl timeout on the private box).
