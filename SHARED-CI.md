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

The shared scripts and workflows expect this repository to follow the
[Tekton Catalog structure][tekton-catalog-structure].

They also introduce new elements and conventions, such as the `${task_name}-oci-ta`
directories for [Trusted Artifacts](#trusted-artifacts) tasks.

Putting it all together, the structure is as follows:

```text
task                                    👈 all tasks go here
├── hello                               👈 the name of a task
│   └── 0.1                             👈 a specific version of the task
│       ├── hello.yaml                  👈 ${task_name}.yaml
│       └── README.md
└── hello-oci-ta                        👈 ${task_name}-oci-ta for Trusted Artifacts
    └── 0.1
        ├── hello-oci-ta.yaml
        ├── README.md
        └── recipe.yaml                 👈 triggers auto-generation of the task yaml
```

## ☑️ CI workflows

### Trusted Artifacts

- script: [`hack/generate-ta-tasks.sh`](hack/generate-ta-tasks.sh)
  - Generates Trusted Artifacts variants of Tasks. See below for more details.
- workflow: [`.github/workflows/check-ta.yaml`](.github/workflows/check-ta.yaml)
  - Checks that the Trusted Artifacts variants are up to date with their base Tasks.

With Trusted Artifacts (TA), Tasks share files via the use of archives stored in
an image repository and not using attached storage (PersistentVolumeClaims). This
has performance and usability benefits. For more details, see
[ADR36](https://konflux-ci.dev/architecture/ADR/0036-trusted-artifacts.html).

When authoring a Task that needs to share or use files from another Task, the
task author can opt to include the Trusted Artifact variant, by convention in
the `${task_name}-oci-ta` directory. This is necessary for the Task to be usable
in Pipelines that make use of Trusted Artifacts.

To author a Trusted Artifacts variant of a Task, create the `${task_name}-oci-ta`
directory, define a [`recipe.yaml`][recipe.yaml] inside the directory and generate
the TA variant using the [`hack/generate-ta-tasks.sh`](hack/generate-ta-tasks.sh)
script. See the [trusted-artifacts generator] README for more details.

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
