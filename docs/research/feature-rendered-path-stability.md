# Feature rendered-path stability across version bumps

**Answer: yes, stable.** A Firestartr Feature's rendered destination path is
computed from the target entity's name and the Feature's *name* only — never
from its pinned `version`/`ref`. The pinned version only selects which
*source* tarball/ref is fetched and rendered (i.e. it can change file
*contents*), not where the output lands. Empirically, three real version
bumps of the `claims_repo` Feature (`v1.16.2` → `v1` → `v2`) in a live claims
repo left every rendered file's path untouched, changing only a version
stamp inside the file. **Implication:** the one-time symlink from
`~/.agents/skills/` into the rendered path does not need to be recreated on
`fs-forge features update`/re-hydration — it keeps resolving after ordinary
version bumps. The only residual risk is a Feature author choosing to
template `dest` itself off version data, which the renderer permits but is
not how Features are conventionally authored (see caveat below).

## How the destination path is computed

- `render()` in the renderer takes `featureRenderPath` (destination root) and
  `featurePath` (extracted source) as separate arguments, and writes each
  file to `path.join(featureRenderPath, dest)` where `dest` comes from the
  Feature's own `files`/`filesTemplates` config —
  `gitops-k8s/packages/features_renderer/src/render.ts:96` (loop over
  `context.config.files`), `render.ts:99-104` (`destFilePath = path.join(
  featureRenderPath, dest)`). Neither `featureRenderPath` nor `dest` is
  derived from a version argument anywhere in this file.
- The one caveat: before extracting `files`, the *entire* config (including
  every `dest`) is Mustache-rendered against the full render context —
  `render.ts:33-38` (`context.config = JSON.parse(renderContent(JSON.stringify(configData), context))`).
  The context includes `context.traceability` (which carries the resolved
  version/ref, see below), so a Feature author *could* write
  `dest: "foo/{{|traceability.version|}}/bar.md"` and make their own output
  path version-dependent. Nothing in the renderer or schema forbids this
  (`gitops-k8s/packages/features_renderer/src/schema.ts:70-90`, `File`
  definition has no such restriction). This is a per-Feature authoring choice,
  not the default/conventional behavior (see empirical evidence below).
- The caller that supplies `featureRenderPath` is
  `renderFeature()` in
  `gitops-k8s/packages/features_preparer/src/renderer.ts:8-39`, which builds
  it as:
  ```
  renderedPath = common.features.features.getFeatureRenderedPathForEntity(
    featureOwner, featureName, renderPath)
  ```
  (`renderer.ts:27-31`) — and passes `version` only into `extractPath =
  common.features.tarballs.getFeaturesExtractPath(featureName, version,
  owner, repo)` (`renderer.ts:16-23`), the *source* scratch directory under
  `/tmp`.
- `getFeatureRenderedPathForEntity` — the actual destination-path formula —
  is defined at
  `gitops-k8s/packages/catalog_common/src/features/features_io.ts:6-10`:
  ```ts
  export function getFeatureRenderedPathForEntity(entity, featureName, basePath = '/tmp'): string {
    const entityFolderName = `${entity.metadata.name}`.toLowerCase();
    return path.join(basePath, entityFolderName, featureName);
  }
  ```
  Inputs are `basePath` (a fixed render root), `entity.metadata.name` (the
  claim/component name), and `featureName` — **no version/ref parameter at
  all**. Compare with `getFeaturesExtractPath` in
  `gitops-k8s/packages/catalog_common/src/features/tarballs.ts:44-53`, whose
  path *does* fold in `version` (`basicFeaturePath` joins `owner, repo,
  featureName, version`) — but that path is only ever used for the temporary
  extracted source tree, never for the rendered destination.
- The alternate call path used for PR-diff/preview rendering,
  `gitops-k8s/packages/features_preparer/src/installer.ts:38-52`
  (`processFeature` → `renderFeature(featureName, reference, owner, repo,
  featureOwner, '/tmp', featureArgs)`), reaches the same `renderFeature()`/
  `getFeatureRenderedPathForEntity` and has the identical property: `reference`
  (the version/ref) only feeds `downloadFeatureZip`/`getFeaturesExtractPath`
  (source), not the destination.
- Where the version *does* show up in rendered output: as a traceability
  stamp inside file **content**, not in the path.
  `gitops-k8s/packages/features_renderer/src/traceability.ts:6-30` injects a
  `# FEATURE_VERSION: <traceability.version>` comment into rendered
  `.github/workflows/*.yaml` files. `traceability.version` is set to the
  resolved `reference` string (e.g. `claims_repo-v2`) in
  `installer.ts:59-67` (`processFeature`) / equivalently `utils.ts:60-70` in
  `cdk8s_renderer/src/overriders`.

## Update/hydration flow (fs-forge-cli) confirms the claim side never carries a path

- `fs-forge-cli`'s `features edit`/`features add` (the CLI surface for
  bumping a Feature's pinned `version`/`ref` on a `ComponentClaim`) only
  mutate the `providers.github.features[]` entry — `name`, `version`/`ref`,
  `args` — via `mutateFeatureReference()` in
  `gitops-fsforge-new-diff/packages/fs-forge-cli/src/utils/features.ts:47-75`
  and `buildFeatureReference()` (`features.ts:79-102`). There is no `dest`/
  path field anywhere in the `FeatureReference` type
  (`features.ts:5-12`) or in the claim schema; the claim only says *which*
  Feature+version to install, never *where* it lands. Confirmed in
  `reference/fs-forge-features.md:38-40` (this repo): "`features edit`
  carries forward the existing `args`... The reference's own `version`/`ref`
  only pins what the claim stores; it never selects which schema validates
  `args`" — i.e. the claim mutation is scoped to version/args, with
  rendering (and its destination-path logic above) happening entirely
  downstream in the hydration pipeline.
- The hydration workflow (`update-component-features.yaml` /
  `daggerverse/update-claims-features`) re-runs the same render pipeline
  described above on every update; it does not recompute or relocate
  existing rendered files based on the new version — it re-renders into the
  same `getFeatureRenderedPathForEntity` destination and diffs/commits
  content changes.

## Empirical confirmation from a real claims repo

`~/work/prefapp/claims` is a real Firestartr claims repo whose own
`.github/workflows/*.yaml` files are themselves rendered output of the
`claims_repo` Feature (self-hosting: this repo's claim installs the Feature
that manages the repo). Its git history contains three real version bumps of
that Feature (`claims_repo-v1.16.2` → `claims_repo-v1` → `claims_repo-v2`).
For all three tracked output files, `git log --follow` shows **zero path
changes** across every bump — only the `# FEATURE_VERSION:` stamp line
changes:

```
$ git log --follow -p -- .github/workflows/update-component-features.yaml \
    | grep -E "^commit|FEATURE_VERSION"
commit 7e396f2...
-# FEATURE_VERSION: claims_repo-v1
+# FEATURE_VERSION: claims_repo-v2
commit 1e37146...
 # FEATURE_VERSION: claims_repo-v1
commit 7109d73...
-# FEATURE_VERSION: claims_repo-v1.16.2
+# FEATURE_VERSION: claims_repo-v1
```

Same pattern holds for `.github/workflows/update-features.yaml` and
`.github/workflows/uninstall-repository-feature.yaml` in the same repo
(checked with the same `git log --follow -p` command). No renames were
detected by `--follow` in any of the three files across any of the bumps.

(`~/work/pre-vieitesss/claims` was also checked as a second sample repo, but
its single tracked Feature reference — `release_please`/`features_repo` —
has never been version-bumped in its recorded history, so it offers no
additional bump-over-bump evidence; the `prefapp/claims` history above is the
usable empirical sample.)

## Bottom line for the symlink shape

Since (a) the renderer's destination-path formula is a pure function of
entity name + Feature name, never of version, and (b) a real claims repo
shows zero path churn across three actual version bumps, the one-time
symlink from `~/.agents/skills/` into a Feature's rendered path is expected
to **keep resolving correctly across ordinary `fs-forge features
update`/re-hydration cycles**, with no need to recreate it per bump. The one
thing to keep in mind when authoring/reviewing the `firestartr-operation`
Feature's own `config.yaml`: its `files`/`filesTemplates` `dest` entries
should not be templated against `traceability.version` (or any other
version-derived value) if the goal is a symlink-stable path — nothing in the
renderer prevents that pattern, it's just not what stability depends on
avoiding, and not the convention observed in the real repo above.
