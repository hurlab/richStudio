# Synthetic workspace fixtures

No biological or patient data. `annotation.tsv` has twenty annotated genes, ten per term. `query.tsv` selects all ten A genes. The effective annotated universe is twenty, term size ten, query size ten and overlap ten: raw upper-tail probability is `1 / choose(20, 10) = 1 / 184756`. The installed default tested/retained family contains A only, so its BH adjusted value equals its raw value. A separate unrestricted two-term oracle in the test names its exact family explicitly.

`imported-results.tsv` deliberately disagrees between raw and adjusted statistics. Hierarchical selection uses strict raw `Pvalue < 0.05`, dropping D at the boundary; DAVID applies no added significance filter; richR uses the union of supplied comma-separated term genes. Engine-specific memberships are checked without requiring historical numerical equivalence. ProviderExtra must survive unchanged.

`legacy-session-v1.json` is data only. Tests generate a trusted disposable RDS from it; no opaque R object is checked in. This fixture does not establish that arbitrary RDS deserialization is safe.
