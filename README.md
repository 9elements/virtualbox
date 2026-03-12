# VirtualBox Mirror with Version Tags

Fork of [VirtualBox/virtualbox](https://github.com/VirtualBox/virtualbox)
with automatic version tagging.

The upstream repository does not provide git tags for releases. This fork
adds them automatically by scanning `Version.kmk` commit messages for the
release markers that Oracle uses internally.

## Branches

| Branch | Purpose |
|---|---|
| `ci` (default) | GitHub Actions workflows for sync and tagging |
| `main` | Mirror of upstream trunk |
| `VBox-7.1` | Mirror of upstream 7.1.x stable branch |
| `VBox-7.2` | Mirror of upstream 7.2.x stable branch |

Mirror branches are synced from upstream every 6 hours. They are kept as
exact copies -- no additional commits are added.

## Tags

Version tags are created automatically from `Version.kmk` release commits:

| Tag | Example |
|---|---|
| Stable release | `v7.2.6`, `v7.1.16` |
| Pre-release | `v7.2.0-beta1`, `v7.2.0-rc1` |
| Alpha | `v7.0.0-alpha1` |

Browse a specific release:

```
git checkout v7.2.6
```

## How it works

A scheduled GitHub Actions workflow ([sync-and-tag.yml](.github/workflows/sync-and-tag.yml)):

1. Fetches all branches from the upstream VirtualBox repository
2. Fast-forwards the mirror branches (`main`, `VBox-*`)
3. Scans `Version.kmk` commit history for release markers
4. Creates and pushes tags for any new releases detected

The tag detection script ([create-version-tags.sh](.github/scripts/create-version-tags.sh))
can also be run locally:

```bash
# Preview what tags would be created
.github/scripts/create-version-tags.sh --dry-run

# Create tags locally
.github/scripts/create-version-tags.sh

# Create and push tags
.github/scripts/create-version-tags.sh --push
```

