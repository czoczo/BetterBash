package main

import (
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureRepoRefusesToInventALocalCheckout(t *testing.T) {
	cfg := defaultsFor(EnvDevelopment)
	cfg.Repo.Path = filepath.Join(t.TempDir(), "not-checked-out")

	err := setupRepo(cfg)
	if err == nil {
		t.Fatalf("expected an error about the missing working copy")
	}
	if !strings.Contains(err.Error(), "BB_REPO_PATH") {
		t.Errorf("error %q should tell the developer how to fix it", err)
	}
}

func TestEnsureRepoAcceptsAnExistingLocalCheckout(t *testing.T) {
	cfg := defaultsFor(EnvDevelopment)
	cfg.Repo.Path = t.TempDir()

	if err := setupRepo(cfg); err != nil {
		t.Fatalf("setupRepo() returned an error: %v", err)
	}
}

func TestReloadRepoLeavesALocalCheckoutAlone(t *testing.T) {
	repoDir := t.TempDir()
	marker := filepath.Join(repoDir, "uncommitted-change")
	if err := os.WriteFile(marker, []byte("do not reset me\n"), 0o644); err != nil {
		t.Fatalf("failed to seed the working copy: %v", err)
	}

	cfg := defaultsFor(EnvDevelopment)
	cfg.Repo.Path = repoDir

	report, err := reloadRepo(cfg)
	if err != nil {
		t.Fatalf("reloadRepo() returned an error: %v", err)
	}
	if !strings.Contains(report, "working copy") {
		t.Errorf("report %q does not mention the working copy", report)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Errorf("reload removed an uncommitted file from the working copy")
	}
}

// TestDevelopmentDefaultsServeTheWorkingCopy is the guard that keeps `./dev.sh`
// working: with APP_ENV=development and nothing else set, the backend has to
// find the repository it lives in and hand its files out to the installer.
func TestDevelopmentDefaultsServeTheWorkingCopy(t *testing.T) {
	clearEnv(t)
	t.Setenv("APP_ENV", EnvDevelopment)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}
	if err := setupRepo(cfg); err != nil {
		t.Fatalf("setupRepo() returned an error, the development defaults do not work: %v", err)
	}

	a := &app{cfg: cfg}

	t.Run("getbb.sh keeps talking to localhost", func(t *testing.T) {
		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/getbb.sh", nil)
		a.mainRouter(rec, r)

		if rec.Code != http.StatusOK {
			t.Fatalf("GET getbb.sh -> %d: %s", rec.Code, rec.Body.String())
		}
		body := rec.Body.String()
		for _, want := range []string{
			"BB_BASE_URL='http://localhost:8081/vN-y_5uA'",
			"BB_TLS_HOST='localhost'",
			"BB_TLS_PORT='" + defaultDevHTTPSPort + "'",
		} {
			if !strings.Contains(body, want) {
				t.Errorf("served getbb.sh is missing %s\n%s", want, body)
			}
		}
	})

	t.Run("bb.sh gets the theme injected", func(t *testing.T) {
		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/prompt/bb.sh", nil)
		a.mainRouter(rec, r)

		if rec.Code != http.StatusOK {
			t.Fatalf("GET bb.sh -> %d: %s", rec.Code, rec.Body.String())
		}
		if !strings.Contains(rec.Body.String(), "AVATAR=") {
			t.Errorf("served bb.sh has no theme injected")
		}
	})

	t.Run("inputrc is readable", func(t *testing.T) {
		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/.inputrc", nil)
		a.mainRouter(rec, r)

		if rec.Code != http.StatusOK {
			t.Fatalf("GET .inputrc -> %d: %s", rec.Code, rec.Body.String())
		}
	})
}
