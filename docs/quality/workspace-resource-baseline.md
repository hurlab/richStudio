# Workspace resource baseline

## Claim

The installed policy defines a bounded empirical baseline for parsing, archives, table/network rendering and a one-worker four-term engine fixture. The independent security owner approved this bounded foundation scope against technical manifest `699b66567d57747eeb5918e84a44a96d90cda4470fd8a980cba6c99ffb7c7823`; final candidate CI and audit gates remain required. G0 and AC-005 remain open until the clean candidate CI and independent review are accepted. Consumers must call `workspace_check_resources()` before allocating or decoding; this leaf supplies the common boundary, not integration into later leaves.

## Evidence

QA independently executed three serial cases from an external working directory, each wrapped in `timeout 120s /usr/bin/time -v`, with R4.6.1 and the candidate installed at `/tmp/richstudio-workspace-001-lib-20261020/richStudio`. Exact JSON receipts, command/environment/exit records and time output are retained by the QA owner under `.moai/reports/SPEC-WORKSPACE-001/implementation/qa/resource-measurement-round2/`. All three exited0, stderr was empty and temporary cleanup was true. Script SHA256: `dfe77dd27b75c16370182b57b4749920b6f9f32d5e5fe3e6fdfdabc509003b36`.

The bounded workload contains one long random label column and numeric remaining columns. Archive members partition one table; they do not duplicate it. Seed17001 fixes the generated content. The upper case is50000rows ×24columns with maximum string1030bytes. It measures decoded table memory, ZIP expansion/member count/depth, graph/table/history data objects and one actual owned multisession worker. The original parser cases do not measure graph drawing or simultaneous users. The additional actual rendering and owned-worker cases below measure their separately stated workloads.

| Upper-case metric | Observed and configured admission maximum |
|---|---:|
| Upload bytes |58183663|
| Rows / columns |50000 /24|
| Cell string bytes |1030|
| Decoded table bytes |59003608|
| Compressed archive bytes |39203135|
| Expanded archive bytes |58186768|
| Archive members / path components |16 /5|
| Render-table rows |2000|
| Graph nodes / edges |400 /800|
| Workers |1|
| Retained history records |20|
| Temporary disk bytes |269389676|
| Parser-case external peak RSS |305308kB|

Limits use the measured upper envelope directly, with no extrapolated capacity. Target-host headroom and the later real rendering/worker measurements are separately attributed below; these point-in-time observations establish no global concurrency or full-engine capacity guarantee. Raising these limits requires fresh measured evidence and security review. The loader checks every required key, integer/finite/positive values and schema; unknown metrics and above-limit values fail closed. All metrics at their limit pass; each individual value one above its limit fails. A missing/invalid installed policy cannot fall back to source-tree configuration.


## Actual rendering and owned-worker cases

The candidate02 measurement extension uses the same installed policy and preserves its15 numerical limits. QA independently ran `render`, `worker` and `worker-error` serially from an external directory, each as `timeout --kill-after=5s 120s /usr/bin/time -v -o CASE.time.log Rscript --vanilla ABS_SCRIPT CASE ABS_OUTPUT.json`. All exited0. The immutable measurement script SHA256 was `81c713a6500ec67bbf30983525ab787dac728bbdaff9505c475ac08d60253fe6`; each receipt records that SHA and actual installed package origins under the fresh candidate002 private library. Durable QA receipts are in `.moai/reports/SPEC-WORKSPACE-001/implementation/qa/ac005-candidate02/`.

The actual DT widget has2000rows and24columns, with first/last row content, stored row/column counts and final pagination status verified in Chromium at1280x720 and375x667. The graph fixture has400terms on a distance1/2ring, one distinct gene for each of800undirected edges and four incident genes per term. Actual `richR::ggnetwork(...,top=400,weightcut=0)`/GGally `ggplot_build` layers contain400points and800segments; the image is drawn through an actual PNG device and decoded in both browser viewports. This exercises the existing plotting backend; it does not add a400-term control to the app's default top50 network wrapper. The formal candidate-owned browser assertions passed4/4 on QA-generated frozen assets; clean CI regenerates those assets using the same candidate script. Combined DT/network rendering observed peak RSS756832kB in the independent candidate02 process, exceeding the original data-only parser observation.

The owned-worker fixture waits for the actual child PID and an unresolved future before checking admission. workers1 passes; workers2 is rejected before invoking a second future factory. Exactly one PID is launched. The same worker runs the committed four-term fixture through richR, hierarchical and DAVID routes serially. Actual child high-water values were494904kB,495372kB and495372kB; result row counts4,3,4. The success-case parent peak RSS was206700kB, separate from the child495372kB and rendering756832kB observations; these are not a measured simultaneous sum. The success process and a separate intentional-worker-error process both reset the future plan, verify the owned PID is gone and remove their temporary directory. These receipts prove the shared admission boundary and this owned fixture's lifecycle, not006's future scheduler or a global multi-user quota. The50000x24 limit remains a parser/serialization envelope and is not50000-term clustering capacity.006 applies worker/history lifecycle bounds;010/011 measure their route-specific upper computational workloads before broader capacity claims.

## Target-host headroom and resource review

The security owner's authorized read-only probe at2026-10-20T21:15:47Z reported available RAM241548156928bytes and free filesystem space254981259264bytes on Hurlab. The inspected serving/child cgroup leaves reported unlimited memory/CPU limits; one existing worker's RSS was4862876kB with unknown workload/history. This separately observed worker footprint is not a failure/leak claim or a substitute for candidate measurements. The controlled parser/archive, real rendering and small engine cases fit below that point-in-time host headroom; none establishes the simultaneous-session count that the host can sustain. No arbitrary multiplicative capacity extrapolation was used when choosing the policy limits.

Independent resource review disposition: **APPROVE — bounded001 foundation envelope**, communicated on2026-10-20 by the independent security owner after matching the technical25-file manifest, the unchanged15 limits and the QA render/normal-worker/error-worker receipts. The config status `approved-bounded-foundation-envelope` records only that disposition. It approves neither production concurrency, a50000-term engine quota nor006 atomic/global admission. The only post-review source changes are this bounded methods note and that status value; final hash review, clean candidate CI and release acceptance remain separate gates.

## Baseline attribution

Initial source HEAD `d853a9920377f666163a8bcc09585f56ad951b3a`, isolated `workspace-foundation-run` tree, script/config candidate digests retained with each verification. Actual package versions and library origins occur in each QA JSON receipt. Earlier dependency deployment results are not this measurement.

## Gaps

Safe global multi-session capacity and engine-specific upper workloads; history retention/scheduler integration in later leaves; final hash-bound audit and clean CI full-suite/check/coverage. The policy is not a release-readiness assertion.

## Residual risk

Shared-host measurements do not establish production throughput. An earlier measurement flattened archive member paths; its original receipts remain in `resource-measurement/`. The corrected run uses `mode="mirror"` and asserts all ZIP member paths before recording actual depths2/3/5.
