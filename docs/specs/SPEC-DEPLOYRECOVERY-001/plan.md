# Plan — SPEC-DEPLOYRECOVERY-001 v0.1.0

## §A Boundaries and target files

Make the existing deployment's recovery truthful and complete with the smallest
post-preflight correction. A rollback is not complete merely because the old
symlink is restored: its service must restart and pass bounded checks. Preserve
the original failure status and never overwrite a detected third release.

| Target | Authorized change |
|---|---|
|scripts/deploy-r46-release.sh|Only post-preflight publication/recovery and its obsolete runtime messages.|
|scripts/test-deploy-recovery.py|Focused standard-library tests of actual extracted deployment source using mocks.|
|docs/specs/SPEC-DEPLOYRECOVERY-001/|Plan and owner-specific run/sync evidence.|
|Ignored deployment preparation/evidence|Root-owned updated hash pin, remote-copy verification and bounded recovery receipts.|

Logical dependency: validated4bc application source and existing completed
heatmap/CI/portability/figure work remain frozen. Existing source receipts are
context, not evidence that the new recovery behavior has already run.

## §B Ordered milestones

1. **High — Define failure ownership and prove RED.** Independently approve this
   plan. Capture the original publication block, complete preflight-prefix bytes,
   archive pins and protected source hashes. Exercise the actual shell source
   with command mocks, recording the verified missing restart before repair.
2. **High — Correct recovery and boundary handling.** Keep the existing atomic
   publication approach. Decide recovery from the captured previous/candidate
   targets and actual current link; observe switch-boundary interruptions and
   refuse a detected unrelated target. Make each recovery stage explicitly
   checked, prevent recursive traps/errexit truncation, retain the original exit
   code, and use bounded service/HTTP checks before declaring recovery complete.
   Normalize INT/TERM into this same cleanup path with nonzero signal status.
3. **High — Verify controlled failures and independent review.** Run syntax and
   scoped actual-source tests only. Cover failure after restart/health, each
   recovery-stage failure, switch-boundary interruption, changed-owner target,
   ordinary exit codes, INT/TERM, pre-switch failure and successful publication.
   Mock service, filesystem and network operations; bypass real sleeps in tests.
   Confirm release retention, no false success, finite checks and no recursive
   cleanup. Compare frozen bytes/pins and have another actor review the diff.
4. **High — Prepare the exact server command.** Root verifies no prior command
   has started and the live731 release still matches expectations, transfers the
   approved script and updates the prepared wrapper's hash pin. Retain the old
   CI/application preflight attribution and record the identical preflight prefix
   separately from new mocked recovery evidence. Verify syntax and actual remote
   hashes before re-enabling. Production publication and real post-publication
   GUI/service verification remain separately observed operational steps.

## §C Evidence and risk controls

Do not run the local full R suite, R CMD check, coverage or live service failure
tests. This change affects shell recovery, so its meaningful local verification
is actual-source mocked execution plus byte/hash preservation and shell syntax.
Earlier app CI and server preflight remain attributed to their original source
and script. An unchanged preflight prefix supports reuse of that application
build evidence; it is not a fresh run of the corrected publication path.

Do not source or execute the unmodified whole deploy script during tests: it can
build, publish and restart real services. Extract the smallest actual production
region and inject mocks rather than maintaining a separate recovery implementation
that could drift. Test subprocesses have an outer finite timeout and no background
load. Clear mock call logs identify skipped stages and actual call order.

Rollback failure remains operationally possible; print its stage and preserve
both releases and logs. Service health alone does not prove all UI behavior or
prevent every concurrent actor race. Withhold recovery-success claims after a
detected foreign target, restoration failure, inactive service, bad HTTP or app
error page. SIGKILL and host failure cannot be handled by shell traps.

Root owns commits, server preparation and project handoff/log. Implementer owns
only the scoped code/tests and progress E2/E3; Docs owns E4/completion transitions.
No actor should edit the previously completed SPECs or immutable figure archive.
