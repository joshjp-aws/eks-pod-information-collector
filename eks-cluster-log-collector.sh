# #!/bin/bash

#### NOTE #######
#  Line number 74 - 103 of the script will collect all the currently deployed kubernetes resources that are not Namespace bound within the cluster. 
# Such as PVC, SC, PV, WorkerNode information, WebHook Configuration related information to troubleshoot any issue involving these resources. 
# If your present issue does not involve kubernetes resources mentioned above feel free to comment line 72 - 101 before executing the script.


ROOT_OUTPUT_DIR=$PWD
echo "======================================="
echo "Creating a Folder at:  $ROOT_OUTPUT_DIR"
echo "======================================="
kubectl config current-context > clusterName.txt
CLUSTERNAME=$(sed 's/^[^=]*://' clusterName.txt)
TIME=$(date "+%Y%m%d-%Hh:%Mm:%Ss")
OUTPUT_DIR_NAME=$(sed 's|r/|r-|g' <<< "${CLUSTERNAME}").$TIME


OUTPUT_DIR="${OUTPUT_DIR_NAME}"
EXTENSION=${2:-'log'}
echo "======================================="
echo " ${CLUSTERNAME} Log Collected In Folder :  $OUTPUT_DIR"
echo "======================================="
cd $ROOT_OUTPUT_DIR
mkdir "$OUTPUT_DIR"
echo "Collecting Information about kubernetes cluster: ${CLUSTERNAME}, Review file: ClusterDetails.txt "
FILENAME="${OUTPUT_DIR}/ClusterDetails.txt"
kubectl config current-context > "$FILENAME"
echo "==========================" >> "$FILENAME"
kubectl cluster-info >> "$FILENAME"
echo "==========================" >> "$FILENAME"

echo "Collecting ConfigMap details about kubernetes cluster: ${CLUSTERNAME}, Review file: ConfigMap_Info.txt "
CONFIG="${OUTPUT_DIR}/ConfigMap_Info.txt"
echo "[1] =========== AWS-Auth ConfigMap Details ===============" > "$CONFIG"
kubectl describe configmap aws-auth -n kube-system >> "$CONFIG"
echo "[1] =========== END ===============" >> "$CONFIG"
echo "[2] =========== CoreDNS ConfigMap Details ===============" >> "$CONFIG"
kubectl describe configmap coredns -n kube-system >> "$CONFIG"
echo "[2] =========== END ===============" >> "$CONFIG"
echo "[3] =========== Kube-Proxy ConfigMap Details ===============" >> "$CONFIG"
kubectl describe configmap kube-proxy -n kube-system >> "$CONFIG"
echo "[3] =========== END ===============" >> "$CONFIG"




# Collecting All the PODs descriptions/logs running in User Desired Namespace Or by default it will collect pods log running in default namespace
Default_Namespace=${1:-'default'}
echo "Collecting the running POD Logs and Description from  Namespace:  ${Default_Namespace} "
kubectl get ns --no-headers | while read -r line; do
NAMESPACE=$(echo "$line" | awk '{print $1}')
if [[ "$NAMESPACE" = "$Default_Namespace" ]];then
    kubectl get pods -n "$NAMESPACE" --no-headers | while read -r lines; do
            POD_NAME=$(echo "$lines" | awk '{print $1}')
            FILENAME1="${OUTPUT_DIR}/${NAMESPACE}.${POD_NAME}.describe.txt"
            kubectl describe pod -n "$NAMESPACE" "$POD_NAME" > "$FILENAME1"
            for CONTAINER in $(kubectl get po -n "$NAMESPACE" "$POD_NAME" -o jsonpath="{.spec.containers[*].name}"); do
            FILENAME_PREFIX="${OUTPUT_DIR}/${NAMESPACE}.${POD_NAME}.${CONTAINER}"
            
            echo "Collecting Pod "{$POD_NAME}" logs from "{$NAMESPACE}" Namespace "
            FILENAME2="${FILENAME_PREFIX}.current.${EXTENSION}"
            kubectl logs -n "$NAMESPACE" "$POD_NAME" --all-containers=true >"$FILENAME2" 
            
        done 
    done
# Collecting All the K8 resources deployed in user specified namespace 
        echo "Collecting Deployed Resources Info in "{$NAMESPACE}" Namespace "
            FILENAME3="${OUTPUT_DIR}/AllResourcesInfo.txt"
            kubectl get all -n "$NAMESPACE">"$FILENAME3" 

        echo "Collecting recent events log that took place within ${CLUSTERNAME}, Review file: EventsInfo.txt"
            FILENAME4="${OUTPUT_DIR}/EventsInfo.txt"
            kubectl get events --sort-by=.metadata.creationTimestamp -n "$NAMESPACE" > "$FILENAME4"

    
 fi  
done



# Collecting All the Worker-Node level descriptions and their performance metrics informantion.

echo "Collecting information about all the presently running worker node within ${CLUSTERNAME}, Review file: WorkerNodeInfo.txt "
FILENAME6="${OUTPUT_DIR}/WorkerNodeInfo.txt"
kubectl describe node -A > "$FILENAME6"

# Collecting All the information about persistance volume and storage class.

echo "Collecting information about all the persistance volume and storage class deployed ${CLUSTERNAME}, Review file: StorageInfo.txt  "
FILENAME7="${OUTPUT_DIR}/StorageInfo.txt"
echo "[1] ===========Storage Class Details===============" > "$FILENAME7"
kubectl get sc -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"
kubectl describe sc -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"
echo "[2] ===========PersistentVolume Details===============" >> "$FILENAME7"
kubectl get pv -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"
kubectl describe pv -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"
echo "[3] ===========PersistentVolume Claim Details===============" >> "$FILENAME7"
kubectl get pvc -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"
kubectl describe pvc -A >> "$FILENAME7"
echo "==========================" >> "$FILENAME7"

echo "Collecting information about WebHook configured in ${CLUSTERNAME}, Review file: WebHookInfo.txt  "
FILENAME8="${OUTPUT_DIR}/WebHookInfo.txt"
kubectl describe validatingwebhookconfigurations.admissionregistration.k8s.io -A > "$FILENAME8"
kubectl describe mutatingwebhookconfigurations.admissionregistration.k8s.io -A >> "$FILENAME8"



CWD=$(pwd)
cd $ROOT_OUTPUT_DIR || exit 1

echo " ***** INITIALIZING TARBALLING  ***** "
echo "======= Collecting Errors and Failure logs, Review file: FoundErrors.txt ===================" 
FILENAME9="${OUTPUT_DIR}/FoundErrors.txt"
egrep -Ein "fail|err|off" "${OUTPUT_DIR}"/*.${EXTENSION} > "$FILENAME9"
egrep -Ein "fail|err|off" "${OUTPUT_DIR}"/*.txt > "$FILENAME9"
TARBALL_FILE_NAME="${OUTPUT_DIR_NAME}.tar.gz"
echo "- File Created Successfully:  ${TARBALL_FILE_NAME} "
tar -czf "./${TARBALL_FILE_NAME}" "./${OUTPUT_DIR_NAME}" 
mv "./${TARBALL_FILE_NAME}" "$OUTPUT_DIR" 

echo " ***** FINISHING TARBALLING ***** "
echo "==============================================================================="
echo "==== Please Share Below located Tarball Folder on your EKS Support Case ======="
echo "${OUTPUT_DIR}/${TARBALL_FILE_NAME} "
echo "====================================================================="
echo "==== For Further Troubleshooting ======"

echo " - Review Files located at folder :  $OUTPUT_DIR"
echo " - Search for FoundErrors.txt file to check all cluster errors and recent failure "
echo " - Command to search log:  grep -Ei \"fail|err\" ${OUTPUT_DIR}/*.log"

echo "========================== END OF SCRIPT EXECUTION ========================="

cd "$CWD" || exit 1

