# GitHub access handoff

This file records the remaining GitHub work after repository write access is available.

## Current local state

- Branch: `codex/align-mobile-admin-and-api`
- Commit ready to publish: `f131aa1 Align mobile and admin flows with local API`
- Local verification already completed:
  - `flutter analyze` — passed
  - `flutter test --reporter expanded` — 3 tests passed
- Local-only database fixtures are intentionally **not** in Git. They are described in `knowledge_base/data.md`.
- Emulator screenshot PNGs are intentionally uncommitted local evidence, not source assets.

## Access currently failing

The configured GitHub HTTPS account is `maorts14`. A direct push was rejected with:

```text
remote: Permission to ShimonNavon/rescue-alert-system.git denied to maorts14.
fatal: ... 403
```

The available SSH identity was also rejected with `Permission denied (publickey)`.

Grant the chosen GitHub account repository **write** permission to publish the branch. Grant **triage** (or write) permission to create/apply labels on issues.

## Publish the branch

After access is granted, run:

```powershell
git push --set-upstream origin codex/align-mobile-admin-and-api
```

Then open a pull request into the repository's intended integration branch. Keep it open for review; do not merge until hosted CI succeeds and a reviewer approves it.

## Create workflow labels

Create these repository labels if they do not already exist:

```powershell
gh label create "wip" --repo ShimonNavon/rescue-alert-system --color FBCA04 --description "Implemented locally; needs further verification before review."
gh label create "in review" --repo ShimonNavon/rescue-alert-system --color 1D76DB --description "Verified locally; awaiting branch push, pull request review, and hosted CI."
```

## Apply issue labels

Apply `in review` to work verified locally but not yet merged:

```text
#15, #16, #17, #18, #19, #20, #22, #23, #24, #25, #30, #31, #32,
#39, #41, #42, #44, #46, #47, #48, #49, #51, #58
```

Apply `wip` to work with an implementation but missing end-to-end or hosted verification:

```text
#13, #14, #28, #29, #33, #34, #35, #36, #40, #60
```

Issues not listed above should remain unchanged until their implementation and evidence are complete.

## Hosted verification after publishing

1. Confirm the GitHub Actions workflow starts for the pushed branch/PR.
2. Fix any CI failures rather than treating local checks as a substitute.
3. Confirm the PR diff does not include local secrets, database volumes, or emulator evidence images.
4. After review and successful hosted CI, merge according to the repository's normal branch policy.
