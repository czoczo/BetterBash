# Golden fixtures for the theme code decoder

`prompt/bb-theme.sh` decodes the eight character theme codes the WebUI puts into
install commands. Its output has to stay what the Go backend used to inject into
`prompt/bb.sh`, because those codes are in the wild (README, bookmarks, shared
links). `tests/test-theme.sh` therefore compares the shell decoder against
`theme-golden.txt` for every code in `theme-codes.txt`.

| File | Contents |
|---|---|
| `theme-codes.txt` | Codes to decode: the production code from the README, structural edge cases (`AAAAAAAA`, `________`, `--------`, a sweep of the last character over the whole alphabet) and random codes. |
| `theme-golden.txt` | `### <code>` followed by the nine assignments (`PRIMARY_COLOR` ... `PATH_COLOR`, `AVATAR`) the Go backend produced for it. |

## Regenerating

The generator ran inside the Go backend, and the backend is no longer in the
tree - it was removed in the commit named "Drop the backend". Bringing it back
for one test run is deliberate work, which is how it should be:

```
git log --oneline --all -- webpage/backend/golden_gen_test.go   # last commit having it
git checkout <that-commit> -- webpage/backend                   # restore the sources
cd webpage/backend
BB_GOLDEN_CODES=../../tests/golden/theme-codes.txt \
BB_GOLDEN_OUT=../../tests/golden/theme-golden.txt \
  go test -run TestGenerateThemeGolden ./...
git restore --staged webpage/backend && rm -rf webpage/backend  # away again
```

The alternative, useful for checking a single code without any Go, is an older
released page: the retired backend answered `GET /<code>/getbb.sh` with the
injected `prompt/bb.sh`, so the colours of a code that is in the wild can be read
from any release tarball or from the archive of an old download. Do not edit
`theme-golden.txt` by hand: a change here means a visible change of colours for
people who installed BetterBash with the same code.
