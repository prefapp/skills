# Deploy service playbook

Wire a Service repo into an App across `{claims_repo}`, `{org}/.firestartr`, `app-<app>`, `{org}/state-argocd`, and the Service repo, or add a Deployment target to an existing App.

**Guide-first and PR-only.** Default to read-only: discover, plan, and walk the client through the ordered steps. Run `app apply` only when the client asks you to land the changes. Every repo is PR-only; commit only on branches and open PRs (`lifecycle.md` Governance). Skip `preflight`; `app plan` runs all checks.

## Scope guards

Confirm from the request and Step 1 discovery before planning. Stop and state why if any fails:

- **Existing shared Helm chart.** Authoring a new chart is out of scope.
- **Target platform already configured** in `{org}/.firestartr/platforms/`. Bootstrapping a cluster or ArgoCD is out of scope.
- **Single-service App** with a platform-managed Service repo in `{claims_repo}`. If the Service repo does not exist yet, run `create-claim` + `lifecycle` first, then return here. Importing an unmanaged repo or wiring a multi-service App is out of scope.

## Step 1: Discover platform candidates

Treat the named service repo as `<service>`. Propose `<app> = <service>` and confirm in one line unless the client already named both.

```bash
npx @firestartr/fs-forge-cli@{version} app discover --app <app> --service <service> --json
npx @firestartr/fs-forge-cli@{version} schema show AppInputs
```

Read candidates and proposals from `discover`: platforms (`tenants`, `envs`), registry aliases, cluster URLs, ArgoCD `slack_channel`, Service `owner` and `system` (including any cross-service disagreement), `release_type`, and proposed `track` per env.

## Step 2: Resolve inputs with the client

Ask one question at a time with a recommended answer (`../SKILL.md`). Skip anything `discover` resolved unambiguously; the CLI derives `state_repo` and namespaces.

1. **Deployment targets (`targets[]`: `platform`, `tenant`, `env`).** Auto-pick a singular `platform` or `tenant`; default `env` to the lowest candidate (such as `dev`) when unspecified.
2. **Cluster API URL (`targets[].cluster_url`).** Always confirm the URL `discover` found in `state-argocd` per target cluster. When `discover` finds no cluster in `state-argocd`, ask the client; `https://kubernetes.default.svc` is the in-cluster address when ArgoCD runs on the target cluster.
3. **Helm chart (`chart.name`, `chart.version`).** Always ask; there is no safe default.
4. **Registry alias (`chart.registry`).** Auto-pick if one alias exists or one has `default: true`. Otherwise ask which existing alias in `docker_registries/` to use; this flow never renders new registries.
5. **Track and flavor (`targets[].track`, `targets[].flavor`).** Propose `discover`'s `track` (`snapshots`, `pre-releases`, or `releases`) for each env and confirm. Ask `flavor` only if non-default.
6. **Release type (`service.release_type`).** Skip if `discover` read it from `release-please-config.json`; otherwise confirm `discover`'s language proposal.
7. **Conditional overrides.** Confirm the discovered ArgoCD `slack_channel` when present. Ask to pick `owner` or `system` only when `discover` reports disagreement across the App's Services. Pass `service.service_names` only when the client overrides `[<service>]`.

## Step 3: Write temp inputs and run `app plan`

Write the resolved YAML matching `AppInputs` to a `mktemp` file outside every repo; never commit it. Run:

```bash
npx @firestartr/fs-forge-cli@{version} app plan --inputs {inputs-file} [--out {render-dir}]
```

Pass `--out {render-dir}` (a `mktemp -d` path) when guiding the client manually so the rendered files are ready to copy. If the org-plan check fails with 403 and the client knows their GitHub org plan, pass `--org-plan free` or `--org-plan paid`.

Show the client:

- **Ordered steps.** Step 1 lands `{claims_repo}` with one PR per claim: `app-<app>`, then Service. The Service PR edits the Service claim to add the `build_and_dispatch_docker_images` and `release_please` Features; tell the client before running `app apply`. Step 2 opens `{org}/.firestartr`, `app-<app>`, and `{org}/state-argocd` in parallel after Step 1 provisions; merge `{org}/.firestartr` first so `app-<app>` validation reads `apps/<app>.yaml`. Step 3 opens the Service repo `.github/make_dispatches.yaml` PR after all Step 2 PRs merge.
- **Conflicts and failed checks.** Format existing-file conflicts (never overwritten) and failed checks as a plain-language client checklist. For a `build-images` failure, `.github/build_images.yaml` belongs to the Service owner. Propose the smallest file holding the flavor keys the check names, each pointing at the repo's Dockerfile, and open the Service-repo PR only after the client confirms.
- **Developer opt-ins** that `plan` notes (`values.yaml` / `global.yaml` / `<service>.yaml`, `AUTO_MERGE`, `extra_artifacts/`, `set: global.chart_version`).

Act on the exit code:

- **Exit 0.** Plan is ready; proceed to Step 4.
- **Exit 1.** Stopping conflict or failed check; stop here and hand the checklist to the client. Treat files already written to `{render-dir}` as a draft; hand them over only after `app plan` exits 0.
- **Exit 2.** Bad inputs or resolve error; fix `{inputs-file}` or discovery/auth errors and re-run `app plan`.

## Step 4: Walk the steps (default) or run `app apply` (on request)

Ask whether the client wants to walk the steps themselves (recommended default) or have you open the PRs with `app apply`.

### Path A: Guide the client (default)

For each step in `plan`'s order:

1. Give the repo, branch, rendered file paths under `{render-dir}`, PR to open, and merge or wait condition before the next step (in Step 2, merge `{org}/.firestartr` before `app-<app>`).
2. After the client finishes a step, re-run `npx @firestartr/fs-forge-cli@{version} app plan --inputs {inputs-file}` to confirm the repo matches and checks clear before moving on.

### Path B: Land via `app apply` (only on explicit request)

Confirm approval of Step 3's plan, then run:

```bash
npx @firestartr/fs-forge-cli@{version} app apply --inputs {inputs-file} \
  --create-issue --issue-title "{goal}" --issue-body "{what the client asked for}"
```

Write `--issue-title` and `--issue-body` in client terms (never "claim"). If an earlier attempt opened issue `{N}`, pass `--issue {N}` instead (`../reference/fs-forge-mutation-shared.md`). Add `--no-wait`, `--timeout <seconds>`, or `--org-plan free|paid` only when needed or requested.

`app apply` lands Step 1 claims through the provision workflow, then opens the Step 2 and Step 3 PRs without merging them. Tell the client to merge the opened PRs in order: `{org}/.firestartr` first, then `app-<app>` and `{org}/state-argocd`, then the Service repo PR.

Act on the exit code:

- **Exit 0.** Done; proceed to Step 5.
- **Exit 1.** Failed or not ready; stop and report completed PRs, pending PRs, and failed checks (`troubleshooting.md`). If Step 1 failed during provisioning after the claim landed on `main`, fix the cause and confirm provisioning succeeded before re-running, because a rerun trusts the claim files on `main` and skips Step 1.
- **Exit 2.** Setup error (bad inputs, auth, or resolve error); stop and report it.
- **Exit 3.** Pending (timeout or `--no-wait`); report the open PRs and merge order, then re-run `app apply --inputs {inputs-file} --issue {N}` once the client merges them.

## Step 5: Report

Summarize in client terms: App, Service, Deployment targets and tracks wired, PRs landed or verified, and remaining client checklist items (such as populating `values.yaml` or triggering the initial state-repo deployment render). Delete `{inputs-file}`, and delete `{render-dir}` once the client no longer needs it.
