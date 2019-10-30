#!/bin/bash
# Copyright (c) 2019 Red Hat, Inc.
# This program and the accompanying materials are made
# available under the terms of the Eclipse Public License 2.0
# which is available at https://www.eclipse.org/legal/epl-2.0/
#
# SPDX-License-Identifier: EPL-2.0
#
# Contributors:
#   Red Hat, Inc. - initial API and implementation

# configuration
PULLREQUEST_NUMBER=0
PR_CHE_THEIA_IMAGE=docker.io/maxura/che-theia
GITHUB_REPOSITORY_ORG=benoitf
GITHUB_REPOSITORY_NAME=che-theia-pr
HOSTED_CHE_INSTANCE=https://che.openshift.io

parse() {
  while [ $# -gt 0 ]; do
    case $1 in
      --pr-number:*)
        PULLREQUEST_NUMBER="${1#*:}"
        shift ;;
      --che-theia-image:*)
        PR_CHE_THEIA_IMAGE="${1#*:}"
        shift ;;
      --gh-repo-org:*)
        GITHUB_REPOSITORY_ORG="${1#*:}"
        shift ;;
      --gh-repo-name)
        GITHUB_REPOSITORY_NAME="${1#*:}"
      shift ;;
      *)
      shift;;
    esac
  done

  if [[ "${PULLREQUEST_NUMBER}" -eq "0" ]] ; then
    echo "Pull Request number parameter with --pr-number:<number> is mandatory"
    exit 1
  fi
}

init() {
    GITHUB_REPOSITORY_URL=https://github.com/${GITHUB_REPOSITORY_ORG}/${GITHUB_REPOSITORY_NAME}
    RAW_GITHUB_EXTERNAL_LINK_PREFIX=https://raw.githubusercontent.com/${GITHUB_REPOSITORY_ORG}/${GITHUB_REPOSITORY_NAME}/master
    TMP_DIR=$(mktemp -d -t che-theia-pr)    
}

clone_repository() {
    # clone che-theia-pr in a temp directory
    git clone ${GITHUB_REPOSITORY_URL} "${TMP_DIR}"

    # create folder in repository
    PR_RELATIVE_DIR=pr-${PULLREQUEST_NUMBER}
    PR_CLONED_DIR=${TMP_DIR}/${PR_RELATIVE_DIR}
    mkdir -p "${PR_CLONED_DIR}"

}

generate_yamls() {
    # Generate meta.yaml from current next configuration
    THEIA_META_YAML=$(curl https://raw.githubusercontent.com/eclipse/che-plugin-registry/master/v3/plugins/eclipse/che-theia/next/meta.yaml | sed "s|docker.io/eclipse/che-theia:next|${PR_CHE_THEIA_IMAGE}:${PULLREQUEST_NUMBER}|" | sed "s|displayName: theia-ide|displayName: theia-ide (PR ${PULLREQUEST_NUMBER})|")


    # Write meta.yaml in this repository
    echo "${THEIA_META_YAML}" > "${PR_CLONED_DIR}"/che-theia-editor.yaml
    META_YAML_LINK=${RAW_GITHUB_EXTERNAL_LINK_PREFIX}/${PR_RELATIVE_DIR}/che-theia-editor.yaml

    DEVFILE_TEMPLATE="
apiVersion: 1.0.0
metadata:
  generateName: pr-che_theia-${PULLREQUEST_NUMBER}-
attributes:
  persistVolumes: 'false'
components:
  - reference: ${META_YAML_LINK}
    type: cheEditor
"

    echo "${DEVFILE_TEMPLATE}" > "${PR_CLONED_DIR}"/che-theia-devfile.yaml

}

commit_and_push_changes() {
    # add & commit & push
    pushd "${PR_CLONED_DIR}" > /dev/null || exit 
    git add ./*.yaml
    git commit -m "Create devfile for custom che-theia for PR ${PULLREQUEST_NUMBER}" || echo "Nothing to commit, files are already there"
    git push origin master || echo "branch is up-to-date"
    popd > /dev/null || exit
}

cleanup() {
    # cleanup
    rm -rf "${TMP_DIR}"
}


generate() {
    init
    parse "$@"
    clone_repository
    generate_yamls
    commit_and_push_changes
    cleanup
    DEVFILE_YAML_LINK=${RAW_GITHUB_EXTERNAL_LINK_PREFIX}/${PR_RELATIVE_DIR}/che-theia-devfile.yaml
}

display_link() {
   echo "${HOSTED_CHE_INSTANCE}/f/?url=${DEVFILE_YAML_LINK}"
}

(
    set -e
    generate  "$@" > output.log 2>&1
    display_link 
)

if [ $? -ne 0 ]; then
  cat output.log
  rm output.log
  exit 1
fi
