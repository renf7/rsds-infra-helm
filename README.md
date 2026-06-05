# rsds-infra-helm

Helm chart that deploys the **RSDS** static company website to AWS EKS and exposes it
at https://rsdsoftware.eu and https://www.rsdsoftware.eu through an AWS Application
Load Balancer (ALB) Ingress with HTTPS terminated by an AWS Certificate Manager (ACM)
certificate.

The container image is built and published by the companion repository
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

## Install

```bash
helm install company-page ./charts/company-page \
  --set image.tag=latest \
  --set ingress.certificateArn=ACM_CERTIFICATE_ARN
```

## Upgrade

Deploy a specific commit's image by using its `git-<sha>` tag:

```bash
helm upgrade company-page ./charts/company-page \
  --set image.tag=git-COMMIT_SHA \
  --set ingress.certificateArn=ACM_CERTIFICATE_ARN
```

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
