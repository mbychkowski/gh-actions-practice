

# ------------- Directory ENV --------------
CUR_DIR=$(shell pwd)
TF_DIR=${CUR_DIR}/terraform
GENAI_DIR=${CUR_DIR}/genai
TEST_DIR=${CUR_DIR}/test

# ------------ Goolge Cloud ENV ------------
PROJECT_ID=$(shell gcloud config list --format 'value(core.project)' 2>/dev/null)
REGION=us-west1
ZONE=us-west1-b

# ------------ Kubernetes ENV --------------
REGISTRY=${REGION}-docker.pkg.dev/${PROJECT_ID}/repo-genai-quickstart
EXT_IP=$(shell kubectl -n genai get svc genai-api -o jsonpath='{.status.loadBalancer.ingress.*.ip}')

infra: tf skaffold

# Authenticate and enable Google Cloud APIs in project
gcloud-init: gcloud-auth gcloud-enable-apis
gcloud-auth:
	gcloud auth application-default login
gcloud-enable-apis:
	gcloud services enable --project ${PROJECT_ID} \
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

# Standup cloud infrastructure with Terraform
tf: tf-vars tf-init tf-plan tf-apply
tf-vars:
	cat ${TF_DIR}/terraform.example.tfvars | sed -e \
		"s:your-unique-project-id:${PROJECT_ID}:g" > ${TF_DIR}/terraform.tfvars
tf-init:
	terraform -chdir=${TF_DIR} init
tf-plan:
	terraform -chdir=${TF_DIR} plan
tf-apply:
	terraform -chdir=${TF_DIR} apply

# Deploy kubernetes manifests with skaffold
skaffold: k8s-auth k8s-set-env skaffold-set-env skaffold-run
k8s-auth:
	gcloud container clusters get-credentials genai-quickstart --zone us-west1-b --project ${PROJECT_ID}
k8s-set-env:
	find . -type f -name "*.yaml" -exec sed -i "s:your-unique-project-id:${PROJECT_ID}:g" {} +
skaffold-set-env:
	echo "SKAFFOLD_DEFAULT_REPO=${REGISTRY}" > ${GENAI_DIR}/skaffold.env
skaffold-run:
	skaffold run \
		--filename ${GENAI_DIR}/skaffold.yaml \
		--default-repo ${REGISTRY} \
		--build-concurrency 0

destroy:
	skaffold delete --filename ${GENAI_DIR}/skaffold.yaml
	terraform -chdir=${TF_DIR} destroy

reset-vars:
	find . -type f -name "*.yaml" -exec sed -i "s:${PROJECT_ID}:your-unique-project-id:g" {} +

tests:
	${TEST_DIR}/test.sh ${EXT_IP}
