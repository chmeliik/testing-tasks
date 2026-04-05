<!--
<TEMPLATED FILE!>
This file comes from the templates at https://github.com/konflux-ci/task-repo-shared-ci.
Please consider sending a PR upstream instead of editing the file directly.
-->

# 🤝 Shared CI setup for Konflux Task repos

Some of the CI scripts and workflows in this repo come from the [task-repo-shared-ci]
template repo.

All the files that come from the template repo have a `<TEMPLATED FILE!>` comment
near the top to help identify them.

## 🍏 Updating the shared CI

Use [`cruft`][cruft] to update the shared CI files to the latest template:

```bash
cruft update --skip-apply-ask --allow-untracked-files
```

Don't forget to commit the `.cruft.json` changes as well to track which
version of the templates you have.

> [!TIP]
> If you have [`uv`][uv] installed, you can run `uvx cruft` and don't need
> to install `cruft` itself.

Your repo also has an automated workflow that periodically checks for updates and
sends automated PRs. See [Shared CI Updater](#shared-ci-updater) for more details.

## 🔧 Making changes

You can edit the shared CI files if necessary, but please consider sending PRs
for the upstream [task-repo-shared-ci] templates to reduce drift and so that
others can benefit from the changes as well.

`cruft` *will* try to respect your custom patches during the update process, but
as you make more local changes you increase the chance of merge conflicts.

## 🌲 Expected repository structure

The shared scripts and workflows expect tasks to be organized under the `task/` directory.
The task YAML file must be named `${task_name}.yaml` and placed under `task/${task_name}/`.

They also introduce new elements and conventions, such as the `${task_name}-oci-ta`
directories for [Trusted Artifacts](#trusted-artifacts) tasks.

For details on how the `tests` directory is used, see [Task Integration Tests](#task-integration-tests).

### Flexible directory structure

Task files can be placed at any nesting level within the task directory:

```text
task/${task_name}/${task_name}.yaml                   👈 flat (recommended)
task/${task_name}/**/${task_name}.yaml                👈 arbitrarily nested
task/${task_name}/${version}/${task_name}.yaml        👈 legacy (version subdir)
```

> [!NOTE]
> The task version is determined by the `app.kubernetes.io/version` label in the task YAML,
> not by the directory structure.

### Example structure

```text
task                                    👈 all tasks go here
├── goodbye                             👈 flat structure (recommended)
│   ├── CHANGELOG.md                    👈 the changelog for this task (required)
│   ├── goodbye.yaml                    👈 task YAML directly in task dir
│   ├── kustomization.yaml
│   ├── migrations
│   │   └── 0.2.sh                      👈 script for migrating to 0.2
│   └── tests                           👈 Test directory
│       ├── test-goodbye.yaml           👈 Test - A Pipeline named test-*.yaml
│       └── pre-apply-task-hook.sh      👈 Optional hook
├── goodbye-oci-ta                      👈 ${task_name}-oci-ta for Trusted Artifacts
│   ├── CHANGELOG.md
│   ├── goodbye-oci-ta.yaml
│   └── recipe.yaml                     👈 triggers auto-generation of the task yaml
├── greet                               👈 nested structure
│   ├── CHANGELOG.md
│   └── subdir
│       └── deep
│           ├── greet.yaml              👈 task YAML in nested subdir
│           └── tests
│               └── test-greet.yaml
├── greet-oci-ta                        👈 TA variant mirrors base task structure
│   ├── CHANGELOG.md
│   └── subdir
│       └── deep
│           ├── greet-oci-ta.yaml
│           └── recipe.yaml
├── hello                               👈 legacy structure with version subdirs
│   ├── CHANGELOG.md
│   └── 0.1                             👈 a specific version of the task
│       ├── hello.yaml                  👈 ${task_name}.yaml
│       └── README.md
└── hello-oci-ta                        👈 TA variant for legacy structure
    ├── CHANGELOG.md
    └── 0.1
        ├── hello-oci-ta.yaml
        ├── README.md
        └── recipe.yaml
```

## ☑️ CI workflows

### Checkton

- script: [`hack/checkton-local.sh`](hack/checkton-local.sh)
  - Allows running checkton locally.
- workflow: [`.github/workflows/checkton.yaml`](.github/workflows/checkton.yaml)
  - Runs ShellCheck on scripts embedded in YAML files.

Checkton is used to lint shell scripts embedded in YAML files (primarily Tekton files).
It does so by running ShellCheck. For more details, see the [checkton project](https://github.com/chmeliik/checkton)

### Task migration

- script: [`hack/create-task-migration.sh`](hack/create-task-migration.sh)
  - Creates a new migration script based on a basic template.
- script: [`hack/validate-migration.sh`](hack/validate-migration.sh)
  - Validates migration scripts.
- workflow: [`.github/workflows/check-task-migration.yaml`](.github/workflows/check-task-migration.yaml)
  - Validates migration scripts.

Task migrations allow task maintainers to introduce changes to Konflux standard
pipelines according to the task updates. By creating migrations, task
maintainers are able to add/remove/update task parameters, change task
execution order, add/remove mandatory task to/from pipelines, etc.

Task maintainers record task changes in `CHANGELOG.md`. If there is any
pipeline changes accordingly, it is also recommended to create a task migration
in order to be applied to user pipelines automatically, that is done by the
[pipeline-migration-tool](https://github.com/konflux-ci/pipeline-migration-tool).

Task migrations are Bash scripts defined in task directories. In general, a
migration consists of a series of pipeline-migration-tool `modify` subcommands
to modify pipeline YAML in order to work with the new version of
task. Developers can do more with task migrations on the pipelines,
e.g. add/remove a task, add/remove/update task parameters, change execution
order of a task, etc.

### `pmt-modify` command

`modify` is a subcommand of pipeline-migration-tool, which does in-place
modification on both Pipeline and PipelineRun definitions.

`pmt` is an alias for the pipeline-migration-tool executable command. In
migration scripts, invoke the command like this:

```bash
pmt modify -f "$pipeline_file" ...
```

> [!IMPORTANT]
> Using `yq -i` to modify pipelines has been deprecated. Task maintainers must
> invoke `pmt modify` in new migrations.

For more information about the command, please refer to [To modify Konflux
pipelines with modify] and `pmt modify --help`.

#### Create a migration

The following is the steps to write a migration:

- Bump task version. Modify label `app.kubernetes.io/version` in the task YAML file.
- Ensure `migrations/` directory exists in the task directory alongside the
  task YAML file.
- Create a migration file under the `migrations/` directory. Its name is in
  form `<new task version>.sh`. Note that the version must match the bumped
  version.

For example, to create a migration for task `goodbye`, migration file should be
present like this:

```
task
└── goodbye
    ├── goodbye.yaml
    └── migrations
        └── 0.2.sh
```

The migration file is a normal Bash script file:

- It accepts a single argument, which is a file path pointing to a
  Pipeline/PipelineRun file including the task bundle update.
- Use `pmt-modify` command to modify pipeline YAML.
- It should be simple and small as much as possible.
- It should be idempotent as much as possible to ensure that the changes are
  not duplicated to the pipeline when run the migration multiple times.
- Pass the `shellcheck` without customizing the default rules.
- Check whether the migration is for all kinds of Konflux pipelines or not. If
  no, skip the pipeline properly in the script, e.g. skip FBC pipeline due
  to [many tasks are removed](https://github.com/konflux-ci/build-definitions/blob/main/pipelines/fbc-builder/patch.yaml)
  from template-build.yaml.
- The pipeline file path and name can be arbitrary. Please do not use the input
  value to check pipeline type or do test in `if-then-else` statement for
  conditional operations.

Here are example steps to create a migration for a task `task-a`:

```bash
yq -i "(.metadata.labels.\"app.kubernetes.io/version\") |= \"0.2.2\"" task/task-a/0.2/task-a.yaml
mkdir -p task/task-a/0.2/migrations || :
cat >task/task-a/0.2/migrations/0.2.2.sh <<EOF
#!/usr/bin/env bash
set -e
pipeline_file=\$1

# add-param subcommand is idempotent. It does not add parameter repeatedly.
pmt modify -f "\$pipeline_file" task task-a add-param pipelinerun-name "\$(context.pipelineRun.name)"
EOF
```

> [!TIP]
> Task selector `(.spec.tasks[], .spec.pipelineSpec.tasks[])` in the above
> example makes it easy to test the migration scripts in local by passing
> Pipeline or PipelineRun YAML file. For example:
> ```bash
> bash task/hello/migrations/0.2.sh /path/to/repo/.tekton/component-a-pull.yaml`
> ```
> Note: ensure `pmt` is available in `$PATH`.

To add a new task to the user pipelines, a migration can be created with a
fictional task update. That is to select a task, bump its version
and create a migration under the task directory.

#### Create a startup migration by the helper script

`./hack/create-task-migration.sh` is a convenient tool to help developers
create a task migration. The script handles most of the details of migration
creation. It generates a startup migration template file, then developers are
responsible for writing concrete script, which usually consists of a series of
`yq` commands, to implement the migration.

Here are a few examples:

To create a migration for the latest major.minor version of task `push-dockerfile`:

```bash
./hack/create-task-migration.sh -t push-dockerfile
```

To get a complete usage: `./hack/create-task-migration.sh -h`

#### Add tasks to Konflux pipelines

Fictional task updates is a way to add tasks to Konflux pipelines. Following
is the workflow:

- Add the new task to the repository. Go through the whole process until
  task bundle is pushed to the registry. If the task to be added exists
  already, skip this step.

- Create a migration for the task:

  - Choose an existing task to act as a fictional update.
  - Create a migration for it:

    ```bash
    ./hack/create-task-migration.sh -t <task name>
    ```

  - Edit the generated migration file, write script to add the task:

    ```bash
    #!/usr/bin/env bash
    pipeline=$1
    name="<task name>"
    bundle_ref="<image reference>"
    # add-task subcommand is idempotent. It does not add a task repeatedly.
    pmt add-task --run-after "<task name>" --bundle-ref "$bundle_ref" "$name" "$pipeline"
    ```

    Add necessary additional code to make the migration work well.

- Commit the updated task YAML file and the migration file and go through the
  review process.

The migration will be applied during next Renovate run scheduled by MintMaker.

### Kustomize Build

- script: [`hack/build-manifests.sh`](hack/build-manifests.sh)
  - Generates task manifest YAML files from Kustomize definitions (kustomize.yaml, patch.yaml)
- workflow: [`.github/workflows/check-kustomize-build.yaml`](.github/workflows/check-kustomize-build.yaml)
  - Checks if all task manifests are up to date (no rebuild required).

With Kustomize, Task manifests are generated and kept consistent across the
repository by composing base definitions (kustomize.yaml) with patches (patch.yaml).
This ensures that all Task YAML manifests are reproducible and remain in sync
with their source definitions.

When authoring or modifying a Task, contributors should update the corresponding
Kustomize files and regenerate the manifests rather than editing the YAML directly.
Use [`hack/build-manifests.sh`](hack/build-manifests.sh) to regenerate the manifests.

### Trusted Artifacts

- script: [`hack/generate-ta-tasks.sh`](hack/generate-ta-tasks.sh)
  - Generates Trusted Artifacts variants of Tasks. See below for more details.
- script: [`hack/missing-ta-tasks.sh`](hack/missing-ta-tasks.sh)
  - Checks that all Tasks that use workspaces have a Trusted Artifacts variant.
- workflow: [`.github/workflows/check-ta.yaml`](.github/workflows/check-ta.yaml)
  - Checks that Tasks have Trusted Artifacts variants and that those variants
    are up to date with their base Tasks.

With Trusted Artifacts (TA), Tasks share files via the use of archives stored in
an image repository and not using attached storage (PersistentVolumeClaims). This
has performance and usability benefits. For more details, see
[ADR36](https://konflux-ci.dev/architecture/ADR/0036-trusted-artifacts).

When authoring a Task that needs to share or use files from another Task, the
task author can opt to include the Trusted Artifact variant, by convention in
the `${task_name}-oci-ta` directory. This is necessary for the Task to be usable
in Pipelines that make use of Trusted Artifacts.

To author a Trusted Artifacts variant of a Task, create the `${task_name}-oci-ta`
directory, define a [`recipe.yaml`][recipe.yaml] inside the directory and generate
the TA variant using the [`hack/generate-ta-tasks.sh`](hack/generate-ta-tasks.sh)
script. See the [trusted-artifacts generator] README for more details.

#### Ignore missing Trusted Artifacts tasks

The `missing-ta-tasks` script supports an ignore file located at one of these paths
(listed in order of precedence from highest to lowest):

- `.github/.ta-ignore.yaml`
- `.ta-ignore.yaml`

```yaml
# Task paths (glob patterns) to ignore
paths:
  - task/hello/0.2/hello.yaml
  - task/another-task/*

# Workspaces that even TA-compatible Tasks can use
# (i.e. workspaces that are not used for sharing data between tasks)
workspaces:
  - netrc-auth
  - git-auth
```

### Shared CI Updater

- workflow: [`.github/workflows/update-shared-ci.yaml`](.github/workflows/update-shared-ci.yaml)

Periodically (every Sunday, by default) checks for updates in the [task-repo-shared-ci]
templates and sends automated PRs.

You can also trigger it manually from the Actions tab of your repo.

> [!NOTE]
> If you've made custom edits to your shared CI files, then the update process
> can encounter merge conflicts. When that happens, the workflow will send the
> PR anyway but with the merge conflicts included. The PR will be in draft state
> and will include a caution note (like this one, but red) with instructions.
>
> If your repository uses Renovate for automated dependency updates, that may increase
> the chance of merge conflicts. See [Conflicts with Renovate](#conflicts-with-renovate)
> for the solution.

#### Required secrets

- `SHARED_CI_UPDATER_APP_ID` - the ID of the updater GitHub app
- `SHARED_CI_UPDATER_PRIVATE_KEY` - the private key for the updater GitHub app

These may already be set globally for your organization. If not, see the instructions
below.

#### Updater GitHub app

The update workflow uses the credentials of a GitHub app to create pull requests,
rather than the default [`GITHUB_TOKEN`][GITHUB_TOKEN]. There are two reasons:

1. PRs created using `GITHUB_TOKEN` cannot trigger `on: pull_request` or `on: push`
   workflows
2. It's not possible to grant `GITHUB_TOKEN` the permission to edit `.github/workflows/`
   files

Since the shared CI updater is *all about* workflows, it needs to use app credentials
to avoid those restrictions.

##### Set up the GitHub app

1. Go to your organization or user settings on GitHub
2. Go to `Developer settings` > `GitHub Apps`
3. Click `New GitHub App`.
4. Configure the app:
   - **GitHub App name**: e.g. `${org_name} shared CI updater`
   - **Homepage URL**: <https://github.com/konflux-ci/task-repo-shared-ci/blob/main/SHARED-CI.md#shared-ci-updater>
   - **Webhook**: uncheck the `☑️ Active` option
   - **Permissions**:
     - **Repository permissions**:
        - Contents: `Read and write`
        - Pull requests: `Read and write`
        - Workflows: `Read and write`

##### Set the required secrets

1. On the app's settings page, copy the App ID number and generate a private key
2. Go to your organization settings (to set the secrets org-wide)
   or your repository settings
3. Go to `Secrets and variables` > `Actions`
4. Create the secrets
   - `SHARED_CI_UPDATER_APP_ID`: the App ID number
   - `SHARED_CI_UPDATER_PRIVATE_KEY`: plaintext content of the private key

#### Conflicts with Renovate

If your repository uses [Renovate], you could frequently get merge conflicts
during the Shared CI updates, because your repository gets GitHub Actions updates
at a different rate than the upstream [task-repo-shared-ci] repository.

To avoid that, your repo gets the [`hack/renovate-ignore-shared-ci.sh`](hack/renovate-ignore-shared-ci.sh)
script. Run this script during the [onboarding process] to add all the Shared CI
workflows to the [`ignorePaths`][renovate-ignorepaths] in your `renovate.json`.
Afterwards, any time the updater workflow brings in a new workflow file, it will
run the script to automatically update `renovate.json`.

This ensures your Shared CI workflows follow the GitHub Actions versions defined
in the upstream reposistory and avoids unnecessary merge conflicts.

[task-repo-shared-ci]: https://github.com/konflux-ci/task-repo-shared-ci
[onboarding process]: https://github.com/konflux-ci/task-repo-shared-ci?tab=readme-ov-file#-onboarding
[cruft]: https://cruft.github.io/cruft
[uv]: https://docs.astral.sh/uv/
[recipe.yaml]: https://github.com/konflux-ci/build-definitions/tree/main/task-generator/trusted-artifacts#configuration-in-recipeyaml
[trusted-artifacts generator]: https://github.com/konflux-ci/build-definitions/tree/main/task-generator/trusted-artifacts
[GITHUB_TOKEN]: https://docs.github.com/en/actions/concepts/security/github_token
[tekton-catalog-structure]: https://github.com/tektoncd/catalog?tab=readme-ov-file#catalog-structure
[Renovate]: https://docs.renovatebot.com/
[renovate-ignorepaths]: https://docs.renovatebot.com/configuration-options/#ignorepaths
