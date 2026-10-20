# Workspace resource baseline

## Claim

The installed policy defines a conservative measured synthetic envelope. It is an admission policy artifact awaiting independent review. G0 and AC-005 remain open until target-host capacity and the real rendering/admission routes are accepted. Consumers must call `workspace_check_resources()` before allocating or decoding; this leaf supplies the common boundary, not integration into later leaves.

## Evidence

QA independently executed three serial cases from an external working directory, each wrapped in `timeout 120s /usr/bin/time -v`, with R4.6.1 and the candidate installed at `/tmp/richstudio-workspace-001-lib-20261020/richStudio`. Exact JSON receipts, command/environment/exit records and time output are retained by the QA owner under `.moai/reports/SPEC-WORKSPACE-001/implementation/qa/resource-measurement-round2/`. All three exited0, stderr was empty and temporary cleanup was true. Script SHA256: `dfe77dd27b75c16370182b57b4749920b6f9f32d5e5fe3e6fdfdabc509003b36`.

The bounded workload contains one long random label column and numeric remaining columns. Archive members partition one table; they do not duplicate it. Seed17001 fixes the generated content. The upper case is50000rows ×24columns with maximum string1030bytes. It measures decoded table memory, ZIP expansion/member count/depth, graph/table/history data objects and one actual owned multisession worker. It does not measure a full browser graph rendering or simultaneous users.

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
| External peak RSS |305308kB|

Limits use the measured upper envelope directly, with no extrapolated capacity. No positive safety-headroom claim is made for the target server: available target RAM/disk, concurrent sessions and real rendering costs remain unmeasured. Raising these limits requires fresh measured evidence and security review. The loader checks every required key, integer/finite/positive values and schema; unknown metrics and above-limit values fail closed. All metrics at their limit pass; each individual value one above its limit fails. A missing/invalid installed policy cannot fall back to source-tree configuration.

## Baseline attribution

Initial source HEAD `d853a9920377f666163a8bcc09585f56ad951b3a`, isolated `workspace-foundation-run` tree, script/config candidate digests retained with each verification. Actual package versions and library origins occur in each QA JSON receipt. Earlier dependency deployment results are not this measurement.

## Gaps

Target-host available RAM/disk and safe multi-session capacity; actual upper-size browser table/graph rendering; history retention lifecycle/admission behavior in later leaves; independent security approval; clean CI full-suite/check/coverage. The policy is not a release-readiness assertion.

## Residual risk

Shared-host measurements do not establish production throughput. An earlier measurement flattened archive member paths; its original receipts remain in `resource-measurement/`. The corrected run uses `mode="mirror"` and asserts all ZIP member paths before recording actual depths2/3/5.
