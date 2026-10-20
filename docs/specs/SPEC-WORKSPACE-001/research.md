# Research and evidence boundaries — SPEC-WORKSPACE-001

## Measured planning baseline

Planning tree: `/home/juhur/PROJECTS/20_libs/richStudio/.moai/worktrees/workspace-evolution-plan`. Executed `git rev-parse HEAD` returned:

```text
06206d050dcae02a2e773a709c5c6119d29f436e
```

Executed SPEC-ID Bash checks returned `PASS` for SPEC-WORKSPACE-001 and SPEC-WS-001 through 012. New IDs were searched before writing; no prior matching IDs were found. The author read the Hur Harness skill, canonical GEARS reference and SPEC frontmatter schema, then validated canonical fields and actual/new target path declarations before authoring. These checks verify plan structure, not app behavior.

Primary canonical `.moai/project/{product,structure,tech}.md` were not present in the inspected paths. Do not invent missing project-document content. Existing DESCRIPTION, README, instruction docs, source modules, current dependency SPEC and canonical configuration provide the available context. No AGENTS.local.md existed in this planning checkout.

## Observed repository facts and implications

Targeted `rg -n`, `sed -n` and file-list reads in this exact tree established:

| Fact | Inspected location | Planning implication; not a runtime claim |
|---|---|---|
| Static Quick Start cards and empty Home server | `R/home_tab.R` | Add real entry actions and preserve current visual identity |
| Existing CSS --rs-* blue/teal/type/spacing tokens | `inst/application/www/custom.css` | Extend tokens, avoid replacing the styling stack |
| Existing Shiny module namespaces and duplicate Visualize labels | `inst/application/app.R` | Use adapters and clarify labels first |
| Future/promises already dispatch enrichment/clustering | `R/enrich_tab.R`, `R/cluster_tab.R` | Improve lifecycle/state ownership; do not describe async as missing |
| Query prefers Padj then Pvalue, rejects zero remaining rows | `R/deg_enrich.R` | Review actual effective rule; preserve empty-query failure |
| Import normalization includes fuzzy column mapping and supplied extra columns | `R/rr_column_handling.R`, upload modules | Ambiguity needs explicit validation; preserve original tables |
| Session format1.0, RDS/JSON load, existing ZIP export | `R/save_tab.R` | Extend saving, retain compatibility; avoid a second competing save subsystem |
| readRDS precedes list/version validation | `R/save_tab.R:272` | Deliberate deserialization boundary required; no exploit established |
| Bulk ZIP export derives member names from labels | `R/save_tab.R` | Generated file IDs and safe member validation need explicit tests; exploitability not measured |
| Existing import UI includes unavailable text-input route | `R/rr_visualize_tab.R` | Disable/explain unavailable controls truthfully |
| Seven tracked R test files; no tracked Node manifest, workflow or Playwright config | `tests/testthat/`, tracked file query |001 must create the maintained browser/CI harness |

The QA specialist measured local R4.6.1, Node25.2.1, npm11.21.0 and availability in the explicit prior private-library chain: testthat3.3.2/covr3.6.5 available, devtools/lintr/languageserver unavailable there. This is a scoped availability probe, not universal machine absence and not a test run. Source declaration count is not passing-test count.

## Pinned richR background observations

The orchestrator's planning probe downloaded the exact public015 archive, verified its SHA and inspected its exported method source. Artifact read by the SPEC author: `.moai/reports/SPEC-WORKSPACE-001/pinned-richr-background-api.log`.

```text
ARCHIVE https://github.com/hurlab/richR/releases/download/v0.1.5/richR_0.1.5.tar.gz
SHA256 0fdca054567c3e6c0ef51512a11ba755ea3694126aa42cbbb051fed3f1b69abf
BYTES 2769042
```

The inspected source exposes and forwards `universe` in GO, KEGG and generic enrich data.frame/Annot methods. Thus a new upstream API/release is not assumed necessary. Existing sibling working-tree source is not substituted for this pinned release evidence.

A separate orchestrator probe actually called installed public richR0.1.5 generic enrichment in the task-private library under local R4.6.1. The author read `.moai/reports/SPEC-WORKSPACE-001/background-oracle-probe.log`:

```text
BASELINE 0.1.5 /tmp/richstudio-dependency-adoption-v015-lib-20261020/richR R 4.6.1
ORACLE N=10 K=5 n=4 k=3 p= 0.26190476190476175
PASS: installed richR 0.1.5 generic enrichment honors explicit annotated background in one small oracle
```

Displayed result A had Pvalue0.2619048 and Padj0.5238095; underlying raw value matched the independent `phyper(2,5,5,4,lower.tail=FALSE)` calculation. This is one generic-route feasibility observation, not GO/KEGG/Reactome complete-contract evidence, invalid-universe handling, an all-family adjustment oracle or deployed custom-background support.005 acceptance still requires those exact public-route scientific checks. A new official upstream release is needed only if an actual remaining gap is verified.

## Inherited deployment evidence, not rerun

The author read sibling `dependency-adoption/.moai/reports/SPEC-DEPENDENCY-001/deployed-verification/report.md`, which records server R4.5.2, deployed commit06206d0, six affected installed-package files passing, exact142-file integrity, native worker libraries and actual browser GO29-row/hierarchical141-cluster/session reload evidence. These are attributed to the earlier deployment run and its explicit limits, not to this planning task.

Its limitations include no full package suite, deterministic KEGG/Reactome rather than real-provider browser coverage, one browser clustering mode, incomplete species/export/concurrency coverage and no full historical lockfile restoration. Its measured GO duration is not a forecast, performance target or general latency baseline for this initiative. Old browser scripts are historical artifacts, not templates for the new locator/no-hard-sleep requirements.

## Team consultation incorporated into tracked contracts

Independent UX, QA and security specialists supplied local planning inputs under `.moai/reports/SPEC-WORKSPACE-001/{ux-plan,qa-plan,security-plan}.md`. The author read them; necessary contracts are incorporated here and in tracked spec/plan/design/acceptance/leaves, so the package is understandable without ignored report files.

- UX: existing IDs first, four independent entries, compact active context, stable handoffs, no forced wizard; all empty/busy/failure/imported/legacy states designed before code.
- QA: one baseline owner; clean installed-package full gates; actual scientific/worker oracles; CLI Chromium; manual accessibility and unfamiliar-user observation; local availability gaps explicit.
- Security: RDS risk before deserialization, bounded transactional data-only bundles, trusted safe legacy bridge feasibility, generated archive filenames, contextual escaping, session-owned jobs, no arbitrary provider fetch/recipe execution, privacy-aware artifacts and measured quotas.

Consultation is planning input, not an independent implementation approval. No automated security scan, threat exploit, fresh UI screenshot, usability study or current full suite was executed by these specialist reviews.

## Canonical policy sources and gaps

Read policy at the primary repository `.moai/config/sections/`, not absent copies in this planning checkout. `quality.yaml` requires TDD/new-feature tests and defines coverage/quality thresholds; `harness.yaml`, `gate.yaml`, `security.yaml` and `lsp.yaml` remain authoritative for their own axes. Numerical thresholds are not duplicated here. 001 defines a generated reviewed tracked policy bundle and exporter including required referenced ast-grep assets/dependency closure, explicit TypeScript configuration, and a separate measured application resource policy/loader; hosted CI validates its source-content digests and materializes canonical relative paths in an isolated policy root. The primary absolute filesystem path is not assumed available remotely. Refresh/review this snapshot when canonical sources change, and block G0 if it or required tooling is unavailable.

QA observed quality LSP requirements while the runtime client is disabled in lsp.yaml; an absent/disabled client is not a diagnostics pass.001 must provide supported diagnostics or record an explicit unresolved policy disposition. Agent security policy is not an application upload/archive/worker quota: app resource limits still need a documented source and representative measurement. Generic frontend configuration does not change the actual R/Shiny stack.

## Claims, gaps and residual risks

**Claim:** The package decomposes all accepted improvement areas into twelve owned, target-declared, testable draft implementation contracts with a continuous dependency/lock dispatch model.

**Evidence:** Plan artifact readback, SPEC-ID checks, canonical field/path validation, dispatch DAG checks and independent plan audit provide structural evidence. Their actual final outputs are recorded by the orchestrator; this research note does not predict a passing verdict.

**Baseline-attribution:** Source inspection at06206d0; pinned public015 source digest and one localR4.6.1 generic oracle as above; historical server evidence explicitly attributed to its prior run.

**Gaps:** All UI implementation, complete scientific feature route/family tests, cancellation/ownership runtime proof, safe legacy bridge feasibility, complete suite/check/coverage, browser journeys, capacity limits, user research, manual accessibility, staging and deployment of this initiative remain future work.

**Residual-risk:** 012 now owns a concrete bounded platform discovery and bridge task;007 additive metadata/writers remain independent. A safe and convenient legacy RDS bridge may require a product/security tradeoff and hold format rollout. Worker termination may be unavailable on some backends. Imported results may lack scientific provenance permanently. Large results may exceed measured resource policy. None is described as a reproduced defect absent runtime evidence.

## Independent audit revision record

Round1 document audit returned FAIL with six planning blockers: unassigned direct-plot intake validation, missing referenced rule assets, late/unowned resource policy, underdefined legacy discovery, missing TypeScript configuration and non-GEARS requirement starts. Revision assigns each concrete producer/consumer, adds SPEC-WS-012 for bounded legacy bridge work, and tightens successful-load generation sequencing. Revised structural/lint/traceability outputs and a focused independent confirming verdict remain separate evidence; no runtime test or isolation probe is claimed.
