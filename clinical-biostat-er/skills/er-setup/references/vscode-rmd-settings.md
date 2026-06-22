# VS Code Rmd Settings

The setup script merges these settings into `.vscode/settings.json` without deleting existing keys:

```json
{
  "r.lsp.enabled": true,
  "files.associations": {
    "*.Rmd": "rmd",
    "*.rmd": "rmd"
  }
}
```

The default target is `current` (the OS running setup is auto-detected). The script manages the matching `r.rpath.<os>` / `r.rterm.<os>` keys for that OS unless another target is requested with `--vscode-r-platform windows|mac|linux`.

When the selected platform matches the OS running the setup script and an R executable is found on PATH, the script sets that platform's R path keys if they are absent:

| OS | Keys |
| --- | --- |
| Windows | `r.rpath.windows`, `r.rterm.windows` |
| macOS | `r.rpath.mac`, `r.rterm.mac` |
| Linux | `r.rpath.linux`, `r.rterm.linux` |

The script also creates or merges `.vscode/extensions.json` with:

```json
{
  "recommendations": ["REditorSupport.r"]
}
```

Existing R paths are preserved. Missing R is reported instead of guessed. With the default `current` target the script writes the R paths for whatever OS you run it on (macOS, Windows, or Linux); pass an explicit `--vscode-r-platform windows|mac|linux` only to manage a different OS's keys (those are written only if they already exist or you run on that OS).
