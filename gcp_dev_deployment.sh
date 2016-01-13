#!/bin/bash

# ---------------STARTING WITH GOOGLE CLOUD: STEP 0------------
ACCOUNT=<your GCE user email>                   # required GCP SDK - get it here -- https://cloud.google.com/sdk/
gcloud auth login $ACCOUNT --brief              # authenticate to GCP from your working directory via Terminal
                                                # will not launch if $ACCOUNT already has credentials
# ------------------- WORKING WITH YOUR DEPLOYMENT -----------------------
# 1. DEPLOY IT
gcloud deployment-manager deployments create my-first-deployment --config vm.yaml

# 2a. SEE STATUS - you can also view on the GCP console
gcloud deployment-manager deployments describe my-first-deployment

# 2b. SEE RESOURCES
gcloud deployment-manager resources list --deployment my-first-deployment

# 3. DELETE IT
gcloud deployment-manager deployments delete my-first-deployment
