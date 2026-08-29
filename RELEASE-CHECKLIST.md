# Release checklist for the composite action

Nothing in this working tree publishes the action. A consumer's
`uses: Yusufihsangorgel/mcp_probe@v0.10.3` resolves only after a human creates
that git tag (and, for Marketplace discovery, a GitHub Release with the
Marketplace box checked). Do not run these steps from an agent session that
was told not to push tags or create releases.

Citations are the GitHub Docs pages as of 2026-08-29.

## What already holds in this repository

- `action.yml` is at the **repository root**. `uses: OWNER/REPO@REF` looks for
  `action.yml` / `action.yaml` there. A file in a subdirectory would be
  referenced as `OWNER/REPO/path@REF` instead.
  ([Metadata syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax);
  [Adding an action from a different repository](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions#adding-an-action-from-a-different-repository))
- Required metadata fields are present: `name`, `description`, `runs`
  (`using: composite` and `steps`). `author` is optional and omitted.
  `branding` is optional; it is set (`icon: check-circle`, `color: blue`), and
  both values are in the documented allow-lists.
  ([Metadata syntax: name, description, runs, branding](https://docs.github.com/en/actions/reference/workflows-and-actions/metadata-syntax))
- The repository is public. A public repository is required for
  `{owner}/{repo}@{ref}` from another repo.
  ([Adding an action from a different repository](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions#adding-an-action-from-a-different-repository))
- The README consumer snippet pins **`v0.10.3`**, matching `version:` in
  `pubspec.yaml`. Remote tags currently stop at `v0.9.8`. **`v0.10.3` does not
  exist until you create it.**

A GitHub Release and a Marketplace listing are **not** required for
`uses:` to resolve. A public repo plus a git ref (tag, branch, or SHA) is.
GitHub recommends tags, not the default branch.
([Managing custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions#using-release-management-for-actions))

## 1. Confirm the action still works

1. `dart analyze --fatal-infos`
2. `dart test`
3. CI job `action` in `.github/workflows/ci.yaml` uses `uses: ./` against
   `test/fixtures/well_behaved_server.dart`. That job must be green on the
   commit you tag.

## 2. Create the version tag `v0.10.3`

GitHub's documented release-management sequence
([Managing custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions#using-tags-for-release-management)):

1. Develop and validate the release (the commit you are about to tag).
2. Create a release with a release tag using semantic versioning
   (for this package: `v0.10.3`).
3. Move a major-version tag to that release (see step 5; optional until 1.0).
4. Introduce a new major tag only for breaking workflow changes (for example
   changing inputs).

Create the annotated tag and push it (do this on the machine that may talk to
GitHub, not as part of a "prepare only" session):

```sh
git tag -a v0.10.3 -m "v0.10.3"
git push origin v0.10.3
```

Or create the tag in the GitHub Release UI in step 3: **Choose a tag** → type
`v0.10.3` → **Create new tag**, with **Target** set to the branch that contains
the `action.yml` you want consumers to run.
([Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release))

Do not create a `v0.10.2` tag on this tree. `0.10.2` is already on pub.dev
from an earlier commit; tagging a later tree with that version would pin
consumers at code that is not what pub shipped. This tree is `0.10.3`. Tag
that.

## 3. Publish a GitHub Release for that tag

From
[Managing releases in a repository](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository#creating-a-release):

1. On GitHub, open the repository home page.
2. To the right of the file list, click **Releases**.
3. Click **Draft a new release**.
4. **Choose a tag**: select `v0.10.3`, or type it and click **Create new tag**.
5. If you created the tag here, set **Target** to the branch with the action.
6. **Release title**: for example `v0.10.3`.
7. **Describe this release**: paste the matching `CHANGELOG.md` section, or
   click **Generate release notes**.
8. Leave **This is a pre-release** unchecked for a production pin.
9. Click **Publish release**. Publishing a release that you also list on
   Marketplace requires two-factor authentication
   ([Publishing actions in GitHub Marketplace](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace#publishing-an-action)).

CLI equivalent from the same page:

```sh
gh release create v0.10.3 --title "v0.10.3" --notes-file CHANGELOG.md
```

Use `gh release create` only after the tag exists or pass the tag so the
command creates it. This step is visible on GitHub; it is maintainer-only.

## 4. List the action on GitHub Marketplace

Required for **discovery** in the Marketplace sidebar, not for `uses:`
resolution. From
[Publishing actions in GitHub Marketplace](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/publish-in-github-marketplace):

Prerequisites GitHub will enforce:

- You have accepted the GitHub Marketplace Developer Agreement.
- The repository is public.
- There is a **single** action metadata file (`action.yml` or `action.yaml`)
  at the repository root. Other `action.yml` files in subfolders are not
  listed automatically.
- The `name` in the metadata file is unique: it must not match another
  Marketplace action, a GitHub user or organization (unless that owner is
  publishing), a Marketplace category, or a reserved GitHub feature name.
  This action's `name` is `mcp_probe conformance`.

Steps:

1. On GitHub, open the repository home page.
2. Open `action.yml`. GitHub shows a banner to publish the action to GitHub
   Marketplace. Click **Draft a release**.
3. Under "Release Action", select **Publish this Action to the GitHub
   Marketplace**.
   - If the checkbox is disabled, the owning account has not accepted the
     GitHub Marketplace Developer Agreement. The owner (or an organization
     owner) must follow the link on that page and accept it.
4. If the metadata has problems, GitHub shows an error or warning. Fix
   `action.yml` and come back. When it is valid you see **Everything looks
   good!**
5. **Primary Category**: pick the category that will help people find the
   action.
6. Optionally pick **Another Category**.
7. **Tag**: `v0.10.3` (this is the version shown on the Marketplace page).
8. **Title**: a release title.
9. Complete the remaining fields and click **Publish release**. Two-factor
   authentication is required.

GitHub also says: when you plan to publish to Marketplace, keep the repository
to the metadata file, code, and files the action needs, so you can tag and
package it as one unit. This repository is a Dart package **with** a root
`action.yml`; that is enough for listing. Splitting the action into its own
repo is a recommendation, not a resolver requirement.

`branding` is optional. It is already set so the Marketplace badge can render.
No further branding fields are required in `action.yml`.

## 5. Optionally maintain a moving major tag

GitHub recommends that **consumers** pin a major version (`@v1`) and that
**maintainers** keep that major tag pointed at the latest compatible release
([Managing custom actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/manage-custom-actions#using-tags-for-release-management);
[Releasing and maintaining actions](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/release-and-maintain-actions)).

This package is still `0.10.3`. The README therefore pins `@v0.10.3`, not
`@v1`. Do not advertise `@v1` until you create that tag and point it at a
release you are willing to treat as the 1.x line. When you do:

```sh
git tag -a v1 v0.10.3 -m "v1 tracks v0.10.3"
git push origin v1
```

On later compatible releases, move it (GitHub documents retargeting the major
tag at the current release; see [Git basics — tagging](https://git-scm.com/book/en/v2/Git-Basics-Tagging)):

```sh
git tag -fa v1 v0.10.4 -m "v1 tracks v0.10.4"
git push origin v1 --force
```

If the repository has **immutable releases** enabled, you cannot force-push a
tag that is tied to a GitHub Release. In that case follow
[Using immutable releases and tags to manage your action's releases](https://docs.github.com/en/actions/how-tos/create-and-publish-actions/using-immutable-releases-and-tags-to-manage-your-actions-releases)
instead of moving release-tied tags.

## 6. After it resolves

1. The README snippet `uses: Yusufihsangorgel/mcp_probe@v0.10.3` should fetch
   `action.yml` from that tag. Confirm with a throwaway workflow in another
   public repository, or by adding a temporary `uses: Yusufihsangorgel/mcp_probe@v0.10.3`
   step in this repo's `action` job.
2. If you listed on Marketplace, the listing page's **Installation** block is
   the syntax GitHub copies for consumers
   ([Adding an action from GitHub Marketplace](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/find-and-customize-actions#adding-an-action-from-github-marketplace)).

## Inputs the action actually ships

Verified against `action.yml` and `.github/workflows/ci.yaml` (the `action`
job passes only `command`):

| Input | Required | Default | Used as |
| --- | --- | --- | --- |
| `command` | yes | — | `MCP_PROBE_COMMAND`; word-split after `mcp_probe check --fail-on … --format …` |
| `fail-on` | no | `error` | `--fail-on` |
| `format` | no | `markdown` | `--format` |
| `version` | no | `''` (latest) | `dart pub global activate mcp_probe $MCP_PROBE_VERSION` |
