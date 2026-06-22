# Core 1 Code Corpus

The files in this directory are reference templates and API indexes for agent
review. Runtime implementation lives under `../scripts/modules/` and
`../scripts/dq_modules/`, loaded through the compatibility entrypoints in
`../scripts/`.

Do not copy implementation bodies from this directory into study Rmd files.
Generated notebooks should source study-local helper snapshots or the runtime
entrypoint and keep only compact orchestration in chunks.
