# GenAI-quickstart-dev

GenAI Quickstart guide for Games on Google Cloud

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html)
- [gcloud](https://cloud.google.com/sdk/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [skaffold](https://skaffold.dev/docs/)

## Getting started

The following steps below will walk you through the setup guide for *GenAI Quickstart*. The process will walk through enabling the proper **Google Cloud APIs**, creating the resources via **Terraform**, and deployment of the **Kubernetes manifests** needed to run the project.

> __Note:__ These steps assume you already have a running project in Google Cloud for which you have IAM permissions to deploy resources into.

### 1) Clone this git repository

```
git clone git@github.com:zaratsian/GenAI-quickstart-dev.git

cd GenAI-quickstart-dev
```

### 2) Set ENV variable

Set your unique Project ID for Google Cloud

```
export PROJECT_ID=$(gcloud config list --format 'value(core.project)' 2>/dev/null)
```

Set default location for Google Cloud

```
export LOCATION=us-west1
```

To better follow along with this quickstart guide, set `CUR_DIR` env variable

```
export CUR_DIR=$(pwd)
```

### 3) Confirm user authentication to Google Cloud project

```
gcloud auth list
```

Check if your authentication is ok and your project_id

```
gcloud projects describe $PROJECT_ID
```

You should see the your `projectId` listed with an `ACTIVE` state.

### 4) Enable Google Cloud APIs

```
gcloud services enable --project $PROJECT_ID \
  aiplatform.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  compute.googleapis.com \
  container.googleapis.com \
  containerfilesystem.googleapis.com \
  containerregistry.googleapis.com \
  iam.googleapis.com \
  servicecontrol.googleapis.com
```

### 5) Deploy infrastructure with Terraform

```
cd $CUR_DIR/terraform

cat terraform.example.tfvars | sed -e "s:your-unique-project-id:$PROJECT_ID:g" > terraform.tfvars

terraform init

terraform plan

terraform apply
```

The deployment of cloud resources can take between 5 - 10 minutes. For a detailed view of the resources deployed see [README](terraform/README.md) in `terraform` directory.

### 6) Setup GKE credentials

After cloud resources have successfully been deployed with Terraform. Get newly created GKE cluster credentials.

```
gcloud container clusters get-credentials genai-quickstart --zone us-west1-b --project $PROJECT_ID
```

### 7) Deploy GenAI workloads on GKE

Switch to the `genai` directory

```
cd $CUR_DIR/genai
```

Set kubernetes manifests for GenAI workloads to use your unique project id

```
find . -type f -name "*.yaml" -exec sed -i "s:your-unique-project-id:$PROJECT_ID:g" {} +
```

Build and run GenAI workloads with **Skaffold**

```
export SKAFFOLD_DEFAULT_REPO=$LOCATION-docker.pkg.dev/$PROJECT_ID/repo-genai-quickstart

# To run all apis and models (requires a GPU node for stable-diffusion)
skaffold run --build-concurrency=0

# To run only stable-diffusion (requires a GPU node)
#skaffold run --module stable-diffusion-api-cfg,stable-diffusion-endpt-cfg

# To run Vertex chat (Vertex AI is required)
#skaffold run --module vertex-chat-api-cfg
```

### 8) Tests

Access the API - You can test the application and all the APIs from here  :)

```
export EXT_IP=`kubectl -n genai get svc genai-api -o jsonpath='{.status.loadBalancer.ingress.*.ip}'`
echo http://${EXT_IP}/genai_docs
```

Test the API (command line - curl)

```
curl -X 'POST' "http://${EXT_IP}/genai/text" \
  -H 'accept: application/json' \
  -H 'Content-Type: application/json' \
  -d '{"prompt": "Who are the founders of Google?"}'
```

## Project cleanup

In `genai` directory

```
cd $CUR_DIR/genai

skaffold delete
```

In `terraform` directory

```
cd $CUR_DIR/terraform

terraform destroy
```

## Troubleshooting

### Not authenticated with Google Cloud project

If you are not running the above project in Google Cloud shell, make sure you are logged in and authenticated with your desired project:

```
gcloud auth application-default login

gcloud config set project <your-unique-project-id>
```

and follow the authentication flow.

## GH SA w/ wi federation

https://github.com/google-github-actions/auth?tab=readme-ov-file#workload-identity-federation-through-a-service-account

### 1) (Optional) Create a Google Cloud Service Account. If you already have a Service Account, take note of the email address and skip this step.

```
gcloud iam service-accounts create sa-tf-gh-actions \
  --project "${PROJECT_ID}"
```

### 2) Create a Workload Identity Pool:

```
gcloud iam workload-identity-pools create "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### 3) Get the full ID of the Workload Identity Pool:

```
gcloud iam workload-identity-pools describe "github" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)"
```

### 4) Create a Workload Identity Provider in that pool:

export GITHUB_ORG=mbychkowsi

```
gcloud iam workload-identity-pools providers create-oidc "gke-github-deployment-mbski" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --display-name="GitHub repo Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '${GITHUB_ORG}'" \
  --issuer-uri="https://token.actions.githubusercontent.com"
```

### 5) Allow authentications from the Workload Identity Pool to your Google Cloud Service Account.

export WORKLOAD_IDENTITY_POOL_ID=projects/273494143447/locations/global/workloadIdentityPools/github

export REPO=mbychkowski/gh-actions-practice

```
gcloud iam service-accounts add-iam-policy-binding "sa-tf-gh-actions@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${WORKLOAD_IDENTITY_POOL_ID}/attribute.repository/${REPO}"
```

### 6) Extract the Workload Identity Provider resource name:

```
gcloud iam workload-identity-pools providers describe "gke-github-deployment-mbski" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github" \
  --format="value(name)"
```

gcloud storage buckets create "gs://bkt-tf-state-${PROJECT_ID}" \
  --project="${PROJECT_ID}" \
  --location=us-central1 \
  --public-access-prevention \
  --uniform-bucket-level-access

gsutil versioning set on "gs://bkt-tf-state-${PROJECT_ID}"