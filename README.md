# public-slice-mirror

Reusable CI building blocks for building a Nix flake, recording its store paths, and mirroring that subset of the closure into a separate FlakeHub cache slice.
This is an implementation detail for Determinate Systems' release process.
The published flake is an implementation detail too.

There are two reusable pieces:

| Piece                                 | Type              | What it does                                                                                                                          |
| ------------------------------------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| `.github/actions/upload-store-paths`  | Composite action  | Writes a list of store paths to `store-paths.txt`, fails if any path in the closure ends in `-source`, and uploads it as an artifact. |
| `.github/workflows/subset-mirror.yml` | Reusable workflow | Downloads that artifact, re-checks the closure, and pushes the paths to FlakeHub.                                                     |

## Using it from another repo

Reference both by their path in this repo, pinned to a ref (a tag or commit SHA
is recommended over `@main`). Below, a `build` job produces the store paths and
hands them to the action; a `mirror` job calls the reusable workflow.

```yaml
name: Mirror to FlakeHub

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v6

      # Nix must be available before upload-store-paths runs — the action's
      # -source closure check uses `nix path-info`.
      - uses: DeterminateSystems/determinate-nix-action@v3
      - uses: DeterminateSystems/flakehub-cache-action@v3

      - name: Build
        id: build
        run: |
          nix build .#default
          echo "store-path=$(readlink -f result)" >> "$GITHUB_OUTPUT"

      # Pass one path, or several newline-separated paths.
      - uses: DeterminateSystems/public-slice-mirror/.github/actions/upload-store-paths@main
        with:
          store-paths: ${{ steps.build.outputs.store-path }}
          # name: store-paths   # optional, this is the default artifact name

  mirror:
    needs: build
    permissions:
      id-token: write   # required so the workflow can auth to FlakeHub
      contents: read
    uses: DeterminateSystems/public-slice-mirror/.github/workflows/subset-mirror.yml@main
    with:
      flake-name: your-org/your-private-flake   # required
      # artifact-name: store-paths              # optional, must match the action's `name`
      # rolling: true                           # optional, default true
      # tag: v1.2.3                             # optional; set rolling: false when using a tag
```

### Passing multiple store paths

The `store-paths` input is a newline-separated list, so you can mirror more than
one output:

```yaml
      - uses: DeterminateSystems/public-slice-mirror/.github/actions/upload-store-paths@main
        with:
          store-paths: |
            ${{ steps.build.outputs.store-path }}
            ${{ steps.other.outputs.store-path }}
```

## Inputs

### `upload-store-paths` action

| Input         | Required | Default       | Description                                |
| ------------- | -------- | ------------- | ------------------------------------------ |
| `store-paths` | yes      | —             | Newline-separated list of Nix store paths. |
| `name`        | no       | `store-paths` | Name of the uploaded artifact.             |

### `subset-mirror` workflow

| Input           | Required | Default       | Description                                                               |
| --------------- | -------- | ------------- | ------------------------------------------------------------------------- |
| `flake-name`    | yes      | —             | FlakeHub flake name to cache against and push to.                         |
| `artifact-name` | no       | `store-paths` | Name of the store-paths artifact to download (match the action's `name`). |
| `rolling`       | no       | `true`        | Push a rolling release. Mutually exclusive with `tag`.                    |
| `tag`           | no       | `""`          | Git tag to publish. Set `rolling: false` when using this.                 |
| `directory`     | no       | `.`           | Directory containing the flake to push.                                   |
