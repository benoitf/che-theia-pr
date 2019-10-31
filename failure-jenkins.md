E2E Happy path tests of Eclipse Che Single User on K8S (minikube v1.1.1) has failed:
- [build details](https://codeready-workspaces-jenkins.rhev-ci-vms.eng.rdu2.redhat.com/view/che-pr-tests/view/K8S/job/$JOB_NAME/$BUILD_ID/)
- [test report](${BUILD_URL}artifact/che/e2e/report/)
- [logs and configs](${BUILD_URL}artifact/logs-and-configs/) 
- "che-theia" docker image: **maxura/che-theia:${ghprbPullId}**
- "che-remote-plugin-node" docker image: **maxura/che-remote-plugin-node:${ghprbPullId}**
- "che-remote-plugin-runner-java8" docker image: **maxura/che-remote-plugin-runner-java8:${ghprbPullId}**
- "che-remote-plugin-kubernetes-tooling-1.0.0" docker image: **maxura/che-remote-plugin-kubernetes-tooling-1.0.0:${ghprbPullId}**
- [Happy path tests DevFile](https://raw.githubusercontent.com/chepullreq4/pr-check-files/master/che-theia/pr-${ghprbPullId}/happy-path-workspace.yaml)
- https://github.com/orgs/eclipse/teams/eclipse-che-qa please check this report.
Use command "crw-ci-test" to rerun the test.
