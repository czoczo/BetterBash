package main

import (
	"net/http/httptest"
	"regexp"
	"strings"
	"testing"
)

// A theme code always encodes to 8 url-safe Base64 characters, so it can never
// collide with the "rand" keyword used by the random theme endpoint.
func TestRandKeywordIsNotAValidThemeCode(t *testing.T) {
	if _, _, _, err := decodeColorLogic(randPathKeyword); err == nil {
		t.Fatalf("%q unexpectedly decodes as a theme code, the rand endpoint would be ambiguous", randPathKeyword)
	}
}

func TestRandomThemeCodeYieldsCompleteThemes(t *testing.T) {
	codePattern := regexp.MustCompile(`^[A-Za-z0-9_-]{8}$`)
	seenCodes := map[string]bool{}

	for i := 0; i < 500; i++ {
		code := randomThemeCode()

		if !codePattern.MatchString(code) {
			t.Fatalf("random theme code %q is not a valid 8 character url-safe Base64 code", code)
		}

		colors, formatted, avatarEnabled, err := decodeColorLogic(code)
		if err != nil {
			t.Fatalf("random theme code %q does not decode: %v", code, err)
		}
		_ = avatarEnabled

		for _, key := range colorComponentKeys {
			value, ok := colors[key]
			if !ok || value == "" {
				t.Fatalf("random theme code %q has no value for %s", code, key)
			}
			if !regexp.MustCompile(`^\\\[\\033\[[01];\d{2}m\\\]$`).MatchString(value) {
				t.Fatalf("random theme code %q produced an unexpected color for %s: %s", code, key, value)
			}
			// Plain black would be invisible on a dark terminal.
			if strings.HasSuffix(value, ";30m\\]") {
				t.Fatalf("random theme code %q produced plain black for %s: %s", code, key, value)
			}
		}

		if !strings.Contains(formatted, "AVATAR='true'") && !strings.Contains(formatted, "AVATAR='false'") {
			t.Fatalf("random theme code %q did not produce an AVATAR flag: %s", code, formatted)
		}

		seenCodes[code] = true
	}

	// With 40+ random bits, collisions over a few hundred draws are vanishingly rare.
	if len(seenCodes) < 400 {
		t.Fatalf("random theme codes are not random enough: only %d unique codes out of 500 draws", len(seenCodes))
	}
}

func TestResolveThemeSegmentKeepsExistingCodes(t *testing.T) {
	r := httptest.NewRequest("GET", "/vN-y_5uA/getbb.sh", nil)

	for _, code := range []string{"vN-y_5uA", "VcrS_H8A", "SomeOtherSegment"} {
		if got := resolveThemeSegment(code, r); got != code {
			t.Fatalf("existing theme code %q was rewritten to %q", code, got)
		}
	}
}

func TestResolveThemeSegmentResolvesRandToFreshCodes(t *testing.T) {
	r := httptest.NewRequest("GET", "/rand/getbb.sh", nil)

	resolved := resolveThemeSegment(randPathKeyword, r)
	if resolved == randPathKeyword {
		t.Fatalf("rand was not resolved to a theme code")
	}
	if _, _, _, err := decodeColorLogic(resolved); err != nil {
		t.Fatalf("rand resolved to a non-decodable segment %q: %v", resolved, err)
	}

	if second := resolveThemeSegment(randPathKeyword, r); second == resolved {
		t.Fatalf("two consecutive rand resolutions returned the same theme code %q", resolved)
	}
}
