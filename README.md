# rsds-infra-helm

Helm chart that deploys the **RSD Software EU** React frontend and Spring Boot authentication service to AWS EKS. Use the [production runbook](docs/PRODUCTION.md), production profile and main-image preparation command below. It exposes the site
at https://rsdsoftware.eu and https://www.rsdsoftware.eu through an AWS Application
Load Balancer (ALB) Ingress with HTTPS terminated by an AWS Certificate Manager (ACM)
certificate.

Both application images are built and published from main by their companion repositories: [rsds-infra-auth-service](https://github.com/renf7/rsds-infra-auth-service) and
[`rsds-infra-company-page`](https://github.com/renf7/rsds-infra-company-page).

```
rsds-infra-helm
└── charts
    └── company-page
        ├── Chart.yaml
        ├── values.yaml
        └── templates
            ├── _helpers.tpl
            ├── deployment.yaml
            ├── service.yaml
            ├── ingress.yaml
            └── NOTES.txt
```

## How it works

- A **Deployment** runs the nginx static-site image (`ClusterIP` Service on port 80).
- An **Ingress** (class `alb`) tells the AWS Load Balancer Controller to create an
  internet-facing ALB.
- The ALB listens on HTTP (80) and HTTPS (443), redirects HTTP → HTTPS, and uses the
  ACM certificate referenced by `ingress.certificateArn` for TLS.
- DNS for both hosts points at the ALB.

## Prerequisites

- Existing EKS cluster: **rsd-software-eks** (region **eu-central-1**).
- `kubectl` configured to talk to the cluster:
  ```bash
  aws eks update-kubeconfig --name rsd-software-eks --region eu-central-1
  ```
- `helm` (v3) installed.
- **AWS Load Balancer Controller** already installed in the cluster.
  This chart does **not** install it.
- An **ACM certificate** in **eu-central-1** covering `rsdsoftware.eu` and
  `www.rsdsoftware.eu`.
- The Docker image available on Docker Hub
  (`renf7/rsds-infra-company-page`).

## Install or upgrade production

Complete the production Secret, external DynamoDB, IAM/service-account and OAuth callback prerequisites in [docs/PRODUCTION.md](docs/PRODUCTION.md) first. The production profile installs exactly the frontend and auth service, with no local test infrastructure.

From a clean current main checkout (PowerShell 7, Git, Helm and Docker CLI/Buildx):

```powershell
git switch main
git pull --ff-only origin main
./scripts/Prepare-Production.ps1
helm upgrade --install company-page ./charts/company-page --kube-context YOUR_EKS_CONTEXT --namespace YOUR_NAMESPACE --create-namespace -f charts/company-page/values-production.yaml -f production-config.yaml -f production-images.json --atomic --wait --timeout 10m
```

Preparation resolves both current service main commits, requires successful main CI/publishing, verifies their registry images and pins immutable digests. It does not deploy. Review the rendered release before installation as shown in the runbook. Rerun preparation before every upgrade; never fall back to latest or reuse a local fixture release's values. `production-config.yaml` contains your infrastructure settings and Secret names, not secret values.

Bare chart defaults are retained for frontend-only compatibility/local tests and are not the production installation procedure.
## Check resources

```bash
kubectl get pods
kubectl get svc
kubectl get ingress
```

## Get the ALB DNS name

```bash
kubectl get ingress company-page
```

The `ADDRESS` column shows the ALB DNS name once the AWS Load Balancer Controller has
provisioned the load balancer (this can take a few minutes).

## DNS setup

Point both hosts at the ALB:

- **Using Route 53:** create **A (Alias)** records for `rsdsoftware.eu` and
  `www.rsdsoftware.eu` that target the ALB.
- **Using another DNS provider:**
  - Create a **CNAME** for `www.rsdsoftware.eu` pointing to the ALB DNS name.
  - For the root domain `rsdsoftware.eu`, use **ALIAS/ANAME** if your provider supports
    it; otherwise move DNS hosting to Route 53 (a root domain cannot use a plain CNAME).

## HTTPS

- The ACM certificate must cover both `rsdsoftware.eu` and `www.rsdsoftware.eu`.
- It must live in **eu-central-1**, because the EKS cluster and ALB are in
  eu-central-1 (ACM certs are region-scoped for ALB).

## Cost note

This chart creates an AWS Application Load Balancer via the Ingress. An ALB has an
ongoing hourly + traffic cost, so it will **increase your monthly AWS bill** for as
long as the release exists.

## Uninstall

```bash
helm uninstall company-page
```

Uninstalling the release should delete the Ingress, which causes the AWS Load Balancer
Controller to remove the ALB. **Verify** in the AWS Console that nothing was left
behind:

- EC2 → Load Balancers
- EC2 → Target Groups
- EC2 → Security Groups

## Production: frontend plus authentication from main

For EKS use [the production release runbook](docs/PRODUCTION.md), `values-production.yaml` and `scripts/Prepare-Production.ps1`. The preparation command resolves both current service main commits and successful image publications into digest-pinned `production-images.json`. It does not deploy. The production profile enables both services and forbids rsds-infra-local/test fixtures; older bare install examples below are frontend-only compatibility examples and are not the production procedure. Production OAuth uses https://www.rsdsoftware.eu; manual local SSO remains fixed at https://localhost:18443.
