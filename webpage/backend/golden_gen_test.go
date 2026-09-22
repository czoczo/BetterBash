package main

import (
	"bufio"
	"fmt"
	"os"
	"strings"
	"testing"
)

// TestGenerateThemeGolden is a development-only generator for the fixture that
// pins the POSIX shell decoder (prompt/bb-theme.sh) to the behaviour of
// decodeColorLogic. It runs only when BB_GOLDEN_OUT names the file to write, so
// the ordinary test run is unaffected.
//
//	cd webpage/backend
//	BB_GOLDEN_OUT=../../tests/golden/theme-golden.txt \
//	BB_GOLDEN_CODES=../../tests/golden/theme-codes.txt \
//	go test -run TestGenerateThemeGolden ./...
//
// Once webpage/backend is deleted the fixture stays in the repository, and the
// generator can be recovered from git history if the corpus ever has to be
// regenerated.
func TestGenerateThemeGolden(t *testing.T) {
	outPath := os.Getenv("BB_GOLDEN_OUT")
	if outPath == "" {
		t.Skip("BB_GOLDEN_OUT is not set, nothing to generate")
	}
	codesPath := os.Getenv("BB_GOLDEN_CODES")
	if codesPath == "" {
		t.Fatalf("BB_GOLDEN_CODES is required together with BB_GOLDEN_OUT")
	}

	codes, err := readLines(codesPath)
	if err != nil {
		t.Fatalf("failed to read codes from %s: %v", codesPath, err)
	}

	out, err := os.Create(outPath)
	if err != nil {
		t.Fatalf("failed to create %s: %v", outPath, err)
	}
	defer out.Close()

	w := bufio.NewWriter(out)
	defer w.Flush()

	fmt.Fprintf(w, "# Golden output of decodeColorLogic (webpage/backend/colors.go) for prompt/bb-theme.sh.\n")
	fmt.Fprintf(w, "# Regenerate with the comment in golden_gen_test.go; do not edit by hand.\n")
	fmt.Fprintf(w, "# Records: '### <code>' followed by the nine assignments the decoder produces.\n")

	for _, code := range codes {
		if code == "" || code == randPathKeyword {
			continue
		}
		_, formatted, _, err := decodeColorLogic(code)
		if err != nil {
			t.Fatalf("decodeColorLogic(%q) failed: %v", code, err)
		}
		fmt.Fprintf(w, "### %s\n%s\n", code, formatted)
	}
	t.Logf("wrote %d records to %s", len(codes), outPath)
}

func readLines(path string) ([]string, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	lines := strings.Split(strings.ReplaceAll(string(data), "\r", ""), "\n")
	kept := make([]string, 0, len(lines))
	for _, line := range lines {
		if strings.TrimSpace(line) == "" {
			continue
		}
		kept = append(kept, strings.TrimSpace(line))
	}
	return kept, nil
}
