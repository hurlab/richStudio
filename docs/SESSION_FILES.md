# Session files

richStudio saves and loads analysis sessions (DEG sets, enrichment results,
clustering results) on the **Save & Load** tab.

## Format: JSON only

- **Save** always produces a `.json` file. Numbers are written with full
  precision (17 significant digits), so p-values and statistics reload exactly.
  Column types and order, `NA` versus empty text, zero-row tables, column names,
  and Unicode labels are preserved. The file keeps `"version": "1.0"`, and a
  `df_schema` block records the table shapes so they restore faithfully.
- **Load** accepts `.json` files only. Files saved by earlier versions as JSON
  still load.
- **`.rds` files are refused.** Reading an RDS file runs R's deserializer, which
  can execute code embedded in the file. On a shared server that is unsafe, so
  the app rejects an `.rds` upload before opening it and changes nothing in your
  current workspace.

## Converting an existing `.rds` session

Do this on your own computer, and only for a file you created or fully trust:

```sh
Rscript scripts/convert-trusted-session.R my-session.rds my-session.json
```

The script is in the richStudio repository. It reads the `.rds`, checks that it
has the richStudio session structure, and writes the JSON with the same writer
the app uses. It never overwrites an existing output file, and it copies only
the known session fields. Upload the resulting `.json` file on the **Load
Session** box.
