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

The generator lives with the Go backend it came from and only runs when asked:

```
cd webpage/backend
BB_GOLDEN_CODES=../../tests/golden/theme-codes.txt \
BB_GOLDEN_OUT=../../tests/golden/theme-golden.txt \
  go test -run TestGenerateThemeGolden ./...
```

Once `webpage/backend` is gone, recover the generator from git history
(`git log --all -- webpage/backend/golden_gen_test.go`) or fix a regression by
comparing against an older release of this repository. Do not edit
`theme-golden.txt` by hand: a change here means a visible change of colours for
people who installed BetterBash with the same code.
