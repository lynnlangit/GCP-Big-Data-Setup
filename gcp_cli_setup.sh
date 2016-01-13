#!/bin/bash

# ---------------STARTING WITH GOOGLE CLOUD: STEP 0------------
ACCOUNT=<your GCE user email>                   # required GCP SDK - get it here -- https://cloud.google.com/sdk/
gcloud auth login $ACCOUNT --brief              # authenticate to GCP from your working directory via Terminal
                                                # will not launch if $ACCOUNT already has credentials
# ------------------- SETUP GCE for Talend ETL: STEPS 1-4 -----------------------
# 1. SET VARIABLES
NUM_AS_SERVERS=1                         # staring with only one job server, using a variable makes adding more servers simpler
ZONE=us-central1-b                       # starting with US zone, could locate in other regions as needed
PROJECT=<your GCE project>               # use your project name
SERVER_INSTANCE_TYPE=n1-standard-8       # starting with standard size, can adjust per load needs
USE_PERSISTENT_DISK=1                    # 0 for in-mem only, 1 for persistent disk
TALEND_IMAGE="https://www.googleapis.com/compute/v1/projects/windows-cloud/global/images/windows-server-2012-r2-dc-v20151006"      # the OS image you use from GCE Images for Talend

SERVER_INSTANCES=`for i in $(seq 1 $NUM_AS_SERVERS); do echo as-server-$i; done`
SERVER_DISKS=`for i in $(seq 1 $NUM_AS_SERVERS); do echo as-persistent-disk-$i; done`
GCLOUD_ARGS="--zone $ZONE --project $PROJECT"

# 2. CREATE SERVER GCE VMS & DISKS
echo "Creating GCE server instances, please wait..."
gcloud compute instances create $GCLOUD_ARGS $SERVER_INSTANCES \
    --machine-type $SERVER_INSTANCE_TYPE --tags "etl-job-server" \
    --image $TALEND_IMAGE --image-project $PROJECT
    /bin/echo "Creating persistent disks..."
gcloud compute disks create $GCLOUD_ARGS $SERVER_DISKS --size "500GB"
    for i in $(seq 1 $NUM_AS_SERVERS); do
        /bin/echo -n "  attaching as-persistent-disk-$i to as-server-$i:"
        gcloud compute instances $GCLOUD_ARGS attach-disk as-server-$i --disk as-persistent-disk-$i
done

# 3. START SERVICES  
/bin/echo "Starting talend daemons..."
for i in $(seq 1 $NUM_AS_SERVERS); do
  /bin/echo -n "  server-$i"
  gcloud compute ssh $GCLOUD_ARGS as-server-$i --ssh-flag="-o LogLevel=quiet" \
      --command "sudo /usr/bin/<talend-daemon> --config-file /etc/<talend>/<talend>.conf"
done
/bin/echo

# 4. START Talend services on server-1
# - Find the public IP of as-server-1, open http://<public ip of server-1>
/bin/echo "Starting Talend console on as-server-1 (external: $server1_external_ip, internal: $server1_ip)"
gcloud compute ssh $GCLOUD_ARGS as-server-1 --ssh-flag="-t" \
    --command "sudo service Talend start" --ssh-flag="-o LogLevel=quiet"
/bin/echo "Talend job server is available at: http://$server1_external_ip:8081"

# ------------------- Setup GCS buckets: STEP 5 -----------------------
# 5. Work with GCS
# -- list existing buckets - folders current (delta processing tables), history and snapshot (machine generated w/timestamp - high vol)
gsutil ls
# -- create bucket(s)
gsutil mb gs://<bucketname1> gs://<bucketname2>

# ------------------- Setup BigQuery: STEP 6 -----------------------
# 6. Work with BigQuery
# -- ls objects
bq ls [<project_id:><dataset_id>]


