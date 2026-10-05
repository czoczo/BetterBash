# Golden fixtures

`prompt/bb-theme.sh` decodes the eight character theme codes the WebUI puts into
install commands. Its output has to stay what the Go backend used to inject into
`prompt/bb.sh`, because those codes are in the wild (README, bookmarks, shared
links). `tests/test-theme.sh` therefore compares the shell decoder against
`theme-golden.txt` for every code in `theme-codes.txt`.

| File | Contents |
|---|---|
| `theme-codes.txt` | Codes to decode: 93 of them, chosen out of the 2 071 once collected - see "Why 93 codes" below. |
| `theme-codes.txt` in history | The full collection of 2 071 codes, for anyone who has to widen the set again. |
| `theme-golden.txt` | `### <code>` followed by the nine assignments (`PRIMARY_COLOR` ... `PATH_COLOR`, `AVATAR`) the Go backend produced for it. |
| `avatars.txt` | `### "<hostname>"` followed by the eight segments (`<glyph><tab><ANSI foreground code>`) `prompt/bb.sh` draws for it. |

## Why 93 codes

The corpus was once 2 071 codes - the production code, structural edge cases and a
field of random ones - because nobody had asked what a code is worth as a test. It
asks now, and the answer is that the decoder of a v0 code reads four things: the value
of each of its eight characters, the five bit field each of the eight colour slots
receives, the 48 bits behind those fields, and the avatar bit. Ninety-three codes show
every value each of those takes anywhere in the old 2 071 - every alphabet character at
every position, every field value in every slot, both values of every bit - and were
found by taking, again and again, the code showing most of what was still unseen, then
keeping the names that are worth having whatever they show (`vN-y_5uA`, and the codes
made of one alphabet character repeated).

Whether that is really enough was checked rather than argued: twenty copies of
`bb_theme_decode_v0` and its helpers, each with one plausible mistake in it - a field
shifted by a bit, the bright bit read for the bold one, the halves of the code split one
bit early, the avatar bit moved, an alphabet character valued wrong, two colour slots
exchanging names - decoded over both sets. Nineteen were caught by both; the twentieth
(such as splitting the halves one bit early) is not a mistake at all but a change the
decoder cannot notice, so the old corpus missed it too. Nothing the 2 071 caught does
the 93 let go.

Regenerating the set is therefore not a matter of taking more codes: a new code is worth
adding when it shows a feature these 93 do not, and the way to look for one is to compare
the features of a candidate with those of the file.

## avatars.txt

This file was not trimmed, and is not the sort of thing to trim: 135 hostnames, most of
them odd on purpose, and a generator that runs (below). Its size is a twentieth of the
theme corpus.

The host avatar is drawn twice: by `hashColor`/`getChar` in `prompt/bb.sh`, and by
`webpage/frontend/src/avatar.js` for the preview on the page. Two implementations
of one look drift, so `tests/test-avatar.mjs` runs the shell functions over a list
of hostnames, compares the JavaScript port with them and with this fixture, and
fails when the page's markup stops drawing an avatar of its own. Unlike the theme
fixtures, this one has a living generator - the shell itself:

```
node tests/test-avatar.mjs --write   # rewrite avatars.txt from prompt/bb.sh
```

## Regenerating the theme fixtures

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
