#!/usr/bin/env bash
set -ex

setup_environment() {
  export CHE_THEIA_META_YAML_URL='https://raw.githubusercontent.com/eclipse/che-plugin-registry/master/v3/plugins/eclipse/che-theia/next/meta.yaml'
  export JAVA_MAVEN_DEVFILE_YAML_URL='https://raw.githubusercontent.com/eclipse/che-devfile-registry/master/devfiles/java-maven/devfile.yaml'
  export NODEJS_DEVFILE_YAML_URL='https://raw.githubusercontent.com/eclipse/che-devfile-registry/master/devfiles/nodejs/devfile.yaml'
  export YQ_TOOL_URL='https://github.com/mikefarah/yq/releases/download/2.4.0/yq_linux_amd64'

  export GITHUB_TOKEN=${GITHUB_TOKEN_ARG}

  export URL_TO_DOWNLOAD_CHECTL='https://github.com/che-incubator/chectl/releases/latest/download/chectl-linux'
  export DEVFILE_URL=${WORKSPACE}/che/tests/e2e/files/happy-path/happy-path-workspace.yaml
  export PR_CHECK_FILES_GITHUB_URL="https://raw.githubusercontent.com/chepullreq4/pr-check-files/master/che-theia/pr-${ghprbPullId}"
  export SUCCESS_THRESHOLD=5

  # set selinux permisive
  sudo setenforce 0

  # stop firewalld
  #sudo systemctl stop firewalld

  # https://github.com/kubernetes/minikube/blob/master/docs/vmdriver-none.md
  export MINIKUBE_WANTUPDATENOTIFICATION=false
  export MINIKUBE_WANTREPORTERRORPROMPT=false
  export MINIKUBE_HOME=$HOME
  export CHANGE_MINIKUBE_NONE_USER=true
  export KUBECONFIG=$HOME/.kube/config
  export DOCKER_CONFIG=$HOME/.docker

  # CRW-344, work around "unable to get local issuer certificate" error
  rm -rf /home/hudson/.npmrc || true
  rm -rf /home/hudson/.yarnrc || true
  
#  npm cache rm
#  npm cache clean --force
#  yarn cache clean --force
  
#  git clone https://chepullreq4:${GITHUB_TOKEN_ARG}@github.com/chepullreq4/pr-check-files.git

  workaround_k8s_error
}

workaround_k8s_error() {
  # https://github.com/eclipse/che/issues/14902
  # https://stackoverflow.com/a/44129137/2556329
  cat /etc/sysctl.conf
  echo "net.bridge.bridge-nf-call-iptables = 1" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
}

printInfo() {
  green=`tput setaf 2`
  reset=`tput sgr0`
  echo "${green}[INFO]: ${1} ${reset}"
}

download_chectl(){
  curl -vsL  https://www.eclipse.org/che/chectl/ > install_chectl.sh
  chmod +x install_chectl.sh
  sudo PATH=$PATH ./install_chectl.sh --channel=next
  sudo chmod +x /usr/local/bin/chectl
}


# build docker image with PR changes and push it to DockerHub repo
build_and_push_docker_image(){
  # CRW-344 use RH NPM mirror
  #sed -i 's|https://registry.yarnpkg.com/|https://repository.engineering.redhat.com/nexus/repository/registry.npmjs.org/|g' ${WORKSPACE}/yarn.lock
  #sed -i 's|https://registry.yarnpkg.com/|https://repository.engineering.redhat.com/nexus/repository/registry.npmjs.org/|g' ${WORKSPACE}/generator/tests/production/assembly/yarn.lock

  ${WORKSPACE}/build.sh --skip-tests --dockerfile:Dockerfile.alpine
  docker login -u maxura -p ${password}

  docker tag eclipse/che-theia:next maxura/che-theia:${ghprbPullId}
  docker push maxura/che-theia:${ghprbPullId}

  docker tag eclipse/che-theia-endpoint-runtime-binary:next maxura/che-theia-endpoint-runtime-binary:${ghprbPullId}
  docker push maxura/che-theia-endpoint-runtime-binary:${ghprbPullId}
}

prepare_meta_yaml() {
  PR_CHECK_FILES_DIR=${WORKSPACE}/pr-check-files/che-theia/pr-${ghprbPullId}

  git clone https://chepullreq4:${GITHUB_TOKEN_ARG}@github.com/chepullreq4/pr-check-files.git
  mkdir -p $PR_CHECK_FILES_DIR

  wget $YQ_TOOL_URL
  sudo chmod +x yq_linux_amd64

  wget $CHE_THEIA_META_YAML_URL -O $PR_CHECK_FILES_DIR/che_theia_meta.yaml
  ./yq_linux_amd64 w -i $PR_CHECK_FILES_DIR/che_theia_meta.yaml spec.containers[0].image maxura/che-theia:${ghprbPullId}
  ./yq_linux_amd64 w -i $PR_CHECK_FILES_DIR/che_theia_meta.yaml spec.initContainers[0].image maxura/che-theia-endpoint-runtime-binary:${ghprbPullId}

  # patch che/tests/e2e/files/happy-path/happy-path-workspace.yaml
  sed -i "s|id: eclipse/che-theia/next|alias: che-theia\n    reference: $PR_CHECK_FILES_GITHUB_URL/che_theia_meta.yaml|" ${DEVFILE_URL}

  # Create the simplest devfile to run
  SIMPLE_RELATIVE_DIR="simple"
  PR_CHECK_FILES_SIMPLE_DIR=${WORKSPACE}/pr-check-files/che-theia/pr-${ghprbPullId}/${SIMPLE_RELATIVE_DIR}
  mkdir -p ${PR_CHECK_FILES_SIMPLE_DIR}
  THEIA_SIMPLE_META_YAML=$(curl ${CHE_THEIA_META_YAML_URL} | sed "s|quay.io/eclipse/che-theia:next|maxura/che-theia:${ghprbPullId}|" | sed "s|displayName: theia-ide|displayName: theia-ide (PR ${ghprbPullId})|")

  # Write meta.yaml in this repository
  echo "${THEIA_SIMPLE_META_YAML}" > "${PR_CHECK_FILES_SIMPLE_DIR}"/che-theia-editor.yaml
  THEIA_SIMPLE_META_YAML_LINK=${PR_CHECK_FILES_GITHUB_URL}/${SIMPLE_RELATIVE_DIR}/che-theia-editor.yaml

  THEIA_SIMPLE_DEVFILE_TEMPLATE="
apiVersion: 1.0.0
metadata:
  generateName: pr-che_theia-${ghprbPullId}-
attributes:
  persistVolumes: 'false'
projects:
  - name: pr-${ghprbPullId}
    source:
      type: git
      location: '${ghprbAuthorRepoGitUrl}'
      branch: '${ghprbSourceBranch}'
components:
  - reference: ${THEIA_SIMPLE_META_YAML_LINK}
    type: cheEditor
"

  echo "${THEIA_SIMPLE_DEVFILE_TEMPLATE}" > "${PR_CHECK_FILES_SIMPLE_DIR}"/che-theia-simple-devfile.yaml
  curl ${JAVA_MAVEN_DEVFILE_YAML_URL} | ./yq_linux_amd64 w - "components[2].reference" ${THEIA_SIMPLE_META_YAML_LINK} | ./yq_linux_amd64 w - "components[2].type" cheEditor | ./yq_linux_amd64 w - "metadata.generateName" "pr-che_theia-maven-${ghprbPullId}-" | ./yq_linux_amd64 w - "attributes.persistVolumes" \"false\" > "${PR_CHECK_FILES_SIMPLE_DIR}"/che-theia-maven-devfile.yaml
  curl ${NODEJS_DEVFILE_YAML_URL} | ./yq_linux_amd64 w - "components[2].reference" ${THEIA_SIMPLE_META_YAML_LINK} | ./yq_linux_amd64 w - "components[2].type" cheEditor | ./yq_linux_amd64 w - "metadata.generateName" "pr-che_theia-nodejs-${ghprbPullId}-" | ./yq_linux_amd64 w - "attributes.persistVolumes" \"false\" > "${PR_CHECK_FILES_SIMPLE_DIR}"/che-theia-nodejs-devfile.yaml
  cat ${DEVFILE_URL}

  cp ${DEVFILE_URL} ${PR_CHECK_FILES_DIR}
  cd ${PR_CHECK_FILES_DIR}
  git add -A
  git diff-index --quiet HEAD || git commit -m "Che PR ${ghprbPullId} files for build: https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/che-pr-tests/view/K8S/job/$JOB_NAME"
  git push

  cd ${WORKSPACE}
}

launch_tests(){
 #CHE_URL=https:$(kubectl get ingress che-ingress -n=che -o=jsonpath={'.spec.rules[0].host'}) # for helm installation
 CHE_URL=https:$(kubectl get ingress che -n=che -o=jsonpath={'.spec.rules[0].host'})

 # pre-pull quay.io/eclipse/happy-path:nightly to avoid start workspace timeout
 docker pull quay.io/eclipse/happy-path:nightly

 docker run --shm-size=1g --net=host --ipc=host \
  -p 5920:5920 \
  -e TS_SELENIUM_HEADLESS='true' \
  -e TS_SELENIUM_DEFAULT_TIMEOUT=300000 \
  -e TS_SELENIUM_LOAD_PAGE_TIMEOUT=240000 \
  -e TS_SELENIUM_WORKSPACE_STATUS_POLLING=20000 \
  -e TS_SELENIUM_BASE_URL=${CHE_URL} \
  -e TS_SELENIUM_LOG_LEVEL='DEBUG' \
  -e TS_SELENIUM_MULTIUSER="true" \
  -e TS_SELENIUM_USERNAME="admin" \
  -e TS_SELENIUM_PASSWORD="admin" \
  -v ${WORKSPACE}/che/tests/e2e:/tmp/e2e:Z \
  -e NODE_TLS_REJECT_UNAUTHORIZED=0 \
  quay.io/eclipse/che-e2e:nightly
}

clone_che_repo() {
  git clone https://github.com/eclipse/che.git
}

######################


start_minikube(){
  echo "---------------------------------- START KUBERNETES ------------------------"

  mkdir -p $HOME/.kube $HOME/.minikube
  touch $KUBECONFIG

  # stop firewalld
  sudo systemctl stop firewalld

  sudo -E /usr/local/bin/minikube start \
      --vm-driver=none \
      --cpus 4 \
      --memory 12288 \
      --logtostderr
}


waitForServerToBeAvailable(){
 #CHE_URL=https://$(kubectl get ingress che-ingress -n=che -o=jsonpath={'.spec.rules[0].host'})  # for helm installation
 CHE_URL=https://$(kubectl get ingress che -n=che -o=jsonpath={'.spec.rules[0].host'})
 COUNTER=0;
 SUCCESS_RATE_COUNTER=0;
 while true; do
  if [ $COUNTER -gt 180 ]; then
   echo "Unable to get stable route. Exiting"
   exit 1
   fi
 
   ((COUNTER+=1))
 
 
   STATUS_CODE=$(curl -k -sL -w "%{http_code}" -I $CHE_URL -o /dev/null; true) || true
 
   echo "Try ${COUNTER}. Status code: ${STATUS_CODE}"
   if [ "$STATUS_CODE" == "200" ]; then 
   	((SUCCESS_RATE_COUNTER+=1))
   fi
   sleep 1;
   
   if [ $SUCCESS_RATE_COUNTER == $SUCCESS_THRESHOLD ]; then 
   	echo "Route is stable enough. Continuing running tests"
   	break
   fi
 done
}


run_chectl() {
  echo "---------------------------------- START CHE ------------------------"
  
  cat > ${WORKSPACE}/custom-resource-patch.yaml <<EOL
spec:
  auth:
    updateAdminPassword: false
EOL
  
  /usr/local/bin/chectl server:start \
   --k8spodreadytimeout=360000 \
   --listr-renderer=verbose \
   --platform=minikube \
   --che-operator-cr-patch-yaml=${WORKSPACE}/custom-resource-patch.yaml

  waitForServerToBeAvailable
}

create_ws_from_devfile(){
	KEYCLOAK_BASE_URL="https://$(kubectl get ingress/keycloak -n che -o jsonpath='{.spec.rules[0].host}')/auth"

	USER_ACCESS_TOKEN=$(curl -k -X POST $KEYCLOAK_BASE_URL/realms/che/protocol/openid-connect/token \
	   -H "Content-Type: application/x-www-form-urlencoded" \
	   -d "username=admin" \
	   -d "password=admin" \
	   -d "grant_type=password" \
	   -d "client_id=che-public" | jq -r .access_token)

	/usr/local/bin/chectl workspace:create --start \
	   --devfile=$DEVFILE_URL \
	   --access-token "$USER_ACCESS_TOKEN"
}


######################


setup_environment
download_chectl
build_and_push_docker_image
start_minikube
clone_che_repo
prepare_meta_yaml
run_chectl
create_ws_from_devfile
launch_tests
