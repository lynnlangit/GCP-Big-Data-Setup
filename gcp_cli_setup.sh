#!/bin/bash
# must manually create new project and set up users, also enable use of GCE, GCS and Big Query APIs (services) using Google Cloud Console
# ---------------STARTING WITH GOOGLE CLOUD: STEP 0------------
ACCOUNT=<your GCE user email>                   # required GCP SDK - get it here -- https://cloud.google.com/sdk/
gcloud auth login $ACCOUNT --brief              # authenticate to GCP from your working directory via Terminal
                                                # will not launch if $ACCOUNT already has credentials

# ------------------- SETUP: STEPS 1-5 -----------------------
# 1a. SET VARIABLES
NUM_AS_SERVERS=1
ZONE=us-central1-b
PROJECT=<your GCE project>               # use your project name
SERVER_INSTANCE_TYPE=n1-standard-8
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

# SETUP PERSISTENT DISKS (optional)
if [ $USE_PERSISTENT_DISK -eq 1 ]
then
    /bin/echo "Creating persistent disks..."
    gcloud compute disks create $GCLOUD_ARGS $SERVER_DISKS --size "500GB"
    for i in $(seq 1 $NUM_AS_SERVERS); do
        /bin/echo -n "  attaching as-persistent-disk-$i to as-server-$i:"
        gcloud compute instances $GCLOUD_ARGS attach-disk as-server-$i --disk as-persistent-disk-$i
    done
fi

# 3a. UPDATE/UPLOAD THE TALEND SETUP & CONFIG FILES
if [ $USE_PERSISTENT_DISK -eq 0 ]
then
    CONFIG_FILE=inmem_only_aerospike.conf
else
    CONFIG_FILE=inmem_and_ondisk_aerospike.conf
fi

/bin/echo "Copying config files..."
for i in $(seq 1 $NUM_AS_SERVERS); do
    /bin/echo -n "  as-server-$i"
    gcloud compute copy-files $GCLOUD_ARGS $CONFIG_FILE as-server-$i:~/aerospike.conf --user-output-enabled=false
    gcloud compute ssh $GCLOUD_ARGS as-server-$i \
        --command "sudo mv ~/aerospike.conf /etc/aerospike/aerospike.conf" \
        --ssh-flag="-o LogLevel=quiet"
done
/bin/echo

# 4b. BOOT SERVERS TO CREATE CLUSTER  
/bin/echo "Starting aerospike daemons..."
for i in $(seq 1 $NUM_AS_SERVERS); do
  /bin/echo -n "  server-$i"
  gcloud compute ssh $GCLOUD_ARGS as-server-$i --ssh-flag="-o LogLevel=quiet" \
      --command "sudo /usr/bin/asd --config-file /etc/aerospike/aerospike.conf"
done
/bin/echo

# 5. START Talend services on server-1
# - Find the public IP of as-server-1, open http://<public ip of server-1>:8081, then http://<internal IP of server-1>:3000
/bin/echo "Starting Talend console on as-server-1 (external: $server1_external_ip, internal: $server1_ip)"
gcloud compute ssh $GCLOUD_ARGS as-server-1 --ssh-flag="-t" \
    --command "sudo service amc start" --ssh-flag="-o LogLevel=quiet"
/bin/echo "Talend job server is available at: http://$server1_external_ip:8081"
/bin/echo "    use cluster seed node: $server1_ip"

# ------------------- Setup GCS buckets: STEPS 6a-c -----------------------
# 6. Work with GCS
# -- list existing buckets
gsutil ls
# -- create bucket(s)
gsutil mb gs://<bucketname1> gs://<bucketname2>



# ------------------- Setup BigQuery: STEPS 7-10 -----------------------
# 7. Work with BigQuery
# -- ls objects
bq ls [<project_id:><dataset_id>]


