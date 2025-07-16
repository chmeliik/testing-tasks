# Testing Tasks

Playing with the Konflux Task builder pipeline.

## CI Setup

Each Task needs a separate Component, ImageRepository etc. in Konflux.

<details>
<summary>Resources for one Task</summary>

```yaml
---
apiVersion: appstudio.redhat.com/v1alpha1
kind: Component
metadata:
  name: git-clone
  annotations:
    build.appstudio.openshift.io/pipeline: '{"name":"tekton-bundle-builder-oci-ta","bundle":"latest"}'
    build.appstudio.openshift.io/request: configure-pac
spec:
  application: testing-tasks
  componentName: git-clone
  source:
    git:
      context: tasks/git-clone
      url: https://github.com/chmeliik/testing-tasks.git
      revision: main
---
apiVersion: appstudio.redhat.com/v1alpha1
kind: ImageRepository
metadata:
  name: git-clone
  annotations:
    image-controller.appstudio.redhat.com/update-component-image: "true"
  labels:
    appstudio.redhat.com/application: testing-tasks
    appstudio.redhat.com/component: git-clone
spec:
  image:
    name: acmiel-tenant/git-clone
    visibility: public
---
apiVersion: appstudio.redhat.com/v1beta2
kind: IntegrationTestScenario
metadata:
  name: git-clone-conforma
spec:
  application: testing-tasks
  contexts:
    - description: Policy check for git-clone task
      name: component_git-clone
  params:
    - name: POLICY_CONFIGURATION
      value: <releng-tenant>/tekton-bundle-standard
  resolverRef:
    params:
      - name: url
        value: https://github.com/konflux-ci/build-definitions
      - name: revision
        value: main
      - name: pathInRepo
        value: pipelines/enterprise-contract.yaml
    resolver: git
```

</details>

Each Task needs two PipelineRun files - one for building on PRs, one for building
on push. All PipelineRuns should reuse one common build Pipeline. See the
[.tekton](.tekton/) directory.

### Handling oci-ta task variants

1. `{task}` and `{task}-oci-ta` will need two separate Components etc. in Konflux.

    ```yaml
    metadata:
      name: git-clone
    spec:
      source:
        git:
          context: task/git-clone
          url: https://github.com/chmeliik/testing-tasks
    ```

    ```yaml
    metadata:
      name: git-clone-oci-ta
    spec:
      source:
        git:
          context: task/git-clone-oci-ta
          url: https://github.com/chmeliik/testing-tasks
    ```

2. We use the [check-ta](.github/workflows/check-ta.yaml) workflow just like we did
  in build-definitions to ensure the oci-ta task YAMLs are up to date with their
  non-oci-ta counterparts. By the time we merge a PR, both the regular task YAML
  and the TA task YAML are in their final form and the build pipeline does not need
  to run the generator again.

    > The [generate-ta-tasks.sh](hack/generate-ta-tasks.sh) script now supports both
    > installing the TA-generator tool from a Go module and building the tool from
    > a local directory.
    >
    > By default, the script installs the tool from
    > `github.com/konflux-ci/build-definitions/task-generator/trusted-artifacts@latest`

3. After merging a PR, we want to release both the regular variant and the TA variant
   at the same time. But this problem is more general - see the [Releasing](#releasing)
   section for more info.

### Releasing

After merging a PR, one push pipeline will run for each Task modified in the PR.
We want to release the Tasks if and only if all the builds succeed and pass Conforma
checks.

That should be the default behavior of the Konflux release pipelines
(see [Single Component Mode], which is disabled by default).

[Single Component Mode]: https://konflux-ci.dev/docs/patterns/testing-releasing-single-component/#enabling-single-component-mode
