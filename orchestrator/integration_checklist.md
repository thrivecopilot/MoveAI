# Integration Checklist (Patch-Based)

Applies to `~/Developer/moveai-review`.

## 0) Inputs
For each TID in `orchestrator/taskboard.md`, confirm the bundle exists:
- `~/Developer/MoveAI/orchestrator/review/<TID>/selfcheck.md`
- `~/Developer/MoveAI/orchestrator/review/<TID>/verify.md`
- Change payload (choose one):
  - `~/Developer/MoveAI/orchestrator/review/<TID>/diff.patch` (default)
  - `~/Developer/MoveAI/orchestrator/review/<TID>/series.patch` (escape hatch)

## 1) Prep (moveai-review)
1. `cd ~/Developer/moveai-review`
2. `git fetch origin`
3. `git checkout main`
4. `git reset --hard origin/main`
5. Create integration branch (example): `git checkout -b codex/integrate-squat-ui-batch2`

## 2) Apply each TID payload + verify + commit
For each TID in the integration order listed on the taskboard:

1. Apply change payload:
   - If `diff.patch` exists:
     - `git apply --index --3way ~/Developer/MoveAI/orchestrator/review/<TID>/diff.patch`
   - Else if `series.patch` exists:
     - `git am --3way ~/Developer/MoveAI/orchestrator/review/<TID>/series.patch`
2. Run verification until PASS:
   - `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review`
3. Commit:
   - If `diff.patch` was used: create **one commit per TID**:
     - `git commit -m "Integrate <TID>: <short title>"`
   - If `series.patch` was used: commits may already be created by `git am`.
     - Either keep the commit series (record SHAs on the taskboard), or squash into one commit per TID.

## 3) Final verification
After all TIDs:
- `bash orchestrator/scripts/verify.sh ~/Developer/moveai-review` → PASS

Optional (only if visuals look risky):
- `bash scripts/capture_screenshots.sh`
- `bash scripts/run_structural_tests.sh`

## 4) Update taskboard evidence
Update `~/Developer/MoveAI/orchestrator/taskboard.md`:
- Mark each TID as INTEGRATED/DONE
- Record integration commit SHA(s)
- Note verification PASS

## 5) Promote to main
In `~/Developer/MoveAI`:
- Merge/fast-forward `main` to include the integration branch (team preference: direct merge vs PR).
- Push to origin.

## 6) Sync other worktrees (optional)
Fast-forward worktrees to the updated `main` as needed:
- `~/Developer/moveai-ios`
- `~/Developer/moveai-ml`
- `~/Developer/moveai-lead`
- `~/Developer/moveai-review`
