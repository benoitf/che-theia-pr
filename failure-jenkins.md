 :x: E2E Happy path failed :heavy_exclamation_mark:

[![Try it](https://chepullreq4.github.io/pr-check-files/live-review.svg)](https://che.openshift.io/f/?url=https://raw.githubusercontent.com/chepullreq4/pr-check-files/master/che-theia/pr-${ghprbPullId}/simple/che-theia-simple-devfile.yaml) 

<details>
<summary>See Details</summary>
<p>

- [Jenkins job](https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/che-pr-tests/view/K8S/job/$JOB_NAME/$BUILD_ID/)

- [test report](${BUILD_URL}artifact/che/e2e/report/)

- [logs and configs](${BUILD_URL}artifact/logs-and-configs/)

- [Happy path tests DevFile](https://raw.githubusercontent.com/chepullreq4/pr-check-files/master/che-theia/pr-${ghprbPullId}/happy-path-workspace.yaml)

- images:

| name | link|
|---|---|
| che-theia | docker.io/maxura/che-theia:${ghprbPullId}|
| che-remote-plugin-node | docker.io/maxura/che-remote-plugin-node:${ghprbPullId}|
| che-remote-plugin-runner-java8 | docker.io/maxura/che-remote-plugin-runner-java8:${ghprbPullId}|
| che-remote-plugin-kubernetes-tooling-1.0.0 | docker.io/maxura/che-remote-plugin-kubernetes-tooling-1.0.0:${ghprbPullId}|

Tested with Eclipse Che Single User on K8S (minikube v1.1.1)

</p>
</details>

:information_source: `Use comment "crw-ci-test" to rerun happy path E2E test.`

