# GeoWake branch and Git-history audit

**Read-only snapshot:** 2026-09-20 17:27:10 UTC. The machine-readable [branch-audit.json](branch-audit.json) pins every local ref and commit bucket; [optional-data-inventory.csv](optional-data-inventory.csv) pins historical recording paths, blob hashes, and byte sizes. The sale worktree was advancing during this audit, so its hash below is a snapshot, not a publication claim. No refs were fetched, pushed, merged, deleted, or rewritten.

## What GitHub currently lists

`origin` is the **private** `Raed2180416/WakePoint` GitHub repository. A live `git ls-remote --symref origin HEAD 'refs/heads/*'` and `gh repo view ... --json isPrivate,defaultBranchRef,pushedAt` returned only three hosted branches:

| Hosted branch | Live revision | Relationship |
|---|---|---|
| Default `stable-release-1` | `50f47ba594baa8098b4c2a37d5ca011a4580986b` | 114 reachable commits; 19 development commits in the 130-commit baseline are absent. |
| `production-ready-audit-v2` | `440e9003cbd3ec7ec78cea0accc56df9cb7d9b2e` | Exact 130-commit development baseline; same as its local branch and `codex/production-readiness`. |
| `ios_branch` | `3dab9fdf6cfaeb3b7758db480af97d8688dc4705` | 53 reachable commits; 51 commits outside the development baseline. Only a remote-tracking ref exists locally. |

There is **no hosted sale/archive branch yet**. The local `codex/geowake-sale-20260920` was `a3ce67106479aaa1a4981a24b80a2a131a495575` (135 reachable commits, five after `440e900`) at this snapshot. Thus the GitHub default and listed branch revisions do **not** yet identify the latest captured local fixes. The sale lineage includes `f4daa94e2100ccac2a698c92d9deef3f7765e523`, the dated capture of pre-existing local fixes/tests, followed by verification/wiring commits; exact commit subjects are in JSON. The primary checkout remains dirty and is not a commit/ref.

## Topology and branch-specific value

Across **all 16 local refs**, including five archive/backup tags and `refs/stash`, there are **201 distinct reachable commits** at this snapshot. They partition without overlap into 130 baseline commits, three release-only commits, 51 iOS-lineage-only commits, five sale-lineage commits, ten tag-only WIP/history commits, and two stash-only commits. Two additional `refs/codex/turn-diffs/...` refs point to the **same tree object**, not commits; they do not add commit history. JSON contains the full SHA and subject of every unique commit. `git rev-list --all --count` matched 201 at this snapshot.

| Lineage | Merge base with `440e900` | Unique commits and substantive tree difference |
|---|---|---|
| `stable-release-1` | `0d5c613d903996baadde4f7702df99d36431a724` | Three release-only commits: `b38c3bc9875bbf1f1da01ccbd83dca2cb78deadd` (website rebuild), `a110cce5228f8c2585c690391b6008479f9e1cb6` (Pages workflow), and `50f47ba594baa8098b4c2a37d5ca011a4580986b` (contact link). Their website assets, claims audit, README and deploy workflow also appear in the development tip; **tip-to-tip `website/index.html` differs by one added line** on release. Commit uniqueness is not the same as exclusive source content. |
| `production-ready-audit-v2` | itself | Nineteen commits after the common release ancestor are absent from stable. They contain later alarm, EKF/real-ride replay, backend cost protection, monetization, Play-compliance and documentation work (for example `3746a0b9d5da4ad9e2e41b40c086ffe2bab64fc5`, `b1b30f52b0b702e7d664927fb3dea144b9de5b57`, `f95692932f8d6051f3b56e742de91e49c9144e3e`). The complete 19-commit list is in JSON. This is the stronger parent for the sale archive. |
| `origin/ios_branch` | `def22beef1898b98e42fbc23a9d852426760710e` | An early divergent July 2025–January 2026 lineage, **51 unique commits**. Its tip has iOS-specific `ios/Podfile`, `ios/Runner/Runner.entitlements`, eight modified iOS project/config files including `AppDelegate.swift` and `Info.plist`; four `lib/` paths absent at the dev tip (older dashboard and GTFS helpers), four `test/` paths absent at the dev tip, and 38 exclusive historical docs including annotated code and EKF plans. Exact paths are in JSON. It also has raw recordings, generated `ios/build/` files, old dependencies, and older versions of core services. |
| Tags and stash | mostly `def22be` | Ten commits are reachable only from the five backup/archive tags after accounting for heads; two more only from `refs/stash`. These preserve January and July WIP, replay investigations and pre-cleanup states. They may support training examples, but are not a newer product baseline. The exact refs and ten/two commit SHAs are in JSON. |

The iOS branch also retains authentic older server, ETA, routing and notification history, including merged PR commits `a95e03a`, `8bc6e61`, and `7f9c449`. The later development baseline has newer implementations of most shared paths. Preserve the iOS ref as historical evidence and compare individual patches before considering any source transplant. Merging its entire tip into the sale line would combine unrelated old service versions, generated build files and private recordings, and create avoidable conflicts. Merging stable wholesale would add little exclusive current code and could obscure the 19 later development commits. Deleting either branch or the tags would discard authentic sequence and WIP context.

## Optional recording evidence, kept separate from source

The private CSV inventories **114 path appearances / 99 unique blobs / 1,417,916,568 unique bytes** under the three identified recording locations. It records exact `source_revision:path`, size and blob SHA without copying sample values:

| Source snapshot | Paths / logical bytes | Current status |
|---|---:|---|
| `origin/ios_branch@3dab9fdf6cfaeb3b7758db480af97d8688dc4705`, `GeoWake IMU  (File responses)/` | 93 / 1,131,362,126 | Present in iOS tip; mixed metro and other phone recordings. |
| `7926de14315322d0dc93eba9e09af4e27375ee7c`, `assets/logs/Nallur_to_Vijaynagar/` | 8 / 149,229,593 | Removed by `bbc3e349ac20f28a0786f637e4c2fefe89bdde50` but present in Git history; **all eight blobs duplicate iOS-tip blobs**, so do not package twice. |
| `production-ready-audit-v2@440e9003cbd3ec7ec78cea0accc56df9cb7d9b2e`, `docs/Sandalsoap-whitefield/` | 13 / 286,554,442 | Present at the dev/sale ancestry tip. |

`git rev-list --objects --all` found **no additional raw blob hashes** under these three prefixes beyond the CSV. The 21 baseline CSVs under `test/fixtures/` were excluded from this optional *real-recording* inventory; research documentation labels replay examples synthetic, and those test fixtures need their own classification. Paths themselves can carry names; `Location.csv`, `Metadata.csv`, and route logs can carry location/device identifiers. The founder says some recordings came from friends' phones, so the optional-data package remains withheld pending per-recording consent, privacy and AI-training-transfer rights. A raw Git mirror or `git bundle --all` would include the historical blobs despite working-tree exclusions.

## Recommended branch presentation

Create one **reviewed canonical archive line**, proposed `archive/2026-09-20`, from the final sale-worktree commit after integration and verification. Its README/manifest should state the exact commit SHA, archived date, intended AI-training use, known failure boundaries, and whether Git history is included. Retain `production-ready-audit-v2`, `stable-release-1`, `ios_branch`, tags and stash in the private provenance store; expose historical refs to a buyer only after the raw-data/asset/secret rights review. Carry the optional recordings in a separate rights-gated package keyed by the CSV blob hashes. If full Git history cannot be transferred, describe a curated source export honestly as an export rather than claiming it is the intact 201-commit repository.

For a GitHub listing, point the buyer at the canonical branch/tag and make that the default only when ready. The final integrity gate is the **same full SHA** in (1) the reviewed local archive ref, (2) live `git ls-remote origin refs/heads/<canonical>` or `gh api`, and (3) the buyer manifest/link. Recompute this audit after the final local commit; the current hosted default still points to the older stable branch.

**Read-only checks used:** `git for-each-ref`, `git rev-list`, `git merge-base`, `git diff --name-status`, `git ls-tree -r -l`, `git rev-list --objects --all`, `git ls-remote`, and `gh repo view`. No builds or tests were run for this branch/history audit.
