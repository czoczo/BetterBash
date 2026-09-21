package main

import (
	"crypto/tls"
	"io"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

const productionHost = "bbb-f4hxb4escnacbpe6.westeurope-01.azurewebsites.net"

// newTestApp builds a backend serving a throwaway checkout, so handlers can be
// exercised without touching the repository.
func newTestApp(t *testing.T, cfg *Config, files map[string]string) *app {
	t.Helper()

	if len(files) > 0 {
		repoDir := t.TempDir()
		for path, content := range files {
			full := filepath.Join(repoDir, path)
			if err := os.MkdirAll(filepath.Dir(full), 0o755); err != nil {
				t.Fatalf("failed to create %s: %v", path, err)
			}
			if err := os.WriteFile(full, []byte(content), 0o644); err != nil {
				t.Fatalf("failed to write %s: %v", path, err)
			}
		}
		cfg.Repo.Path = repoDir
		cfg.Repo.LocalCheckout = true
	}

	return &app{cfg: cfg}
}

func TestSplitHostPort(t *testing.T) {
	cases := []struct {
		rawHost  string
		wantHost string
		wantPort string
		wantHas  bool
	}{
		{rawHost: productionHost, wantHost: productionHost},
		{rawHost: "localhost:8081", wantHost: "localhost", wantPort: "8081", wantHas: true},
		{rawHost: "example.invalid:443", wantHost: "example.invalid", wantPort: "443", wantHas: true},
		{rawHost: "127.0.0.1", wantHost: "127.0.0.1"},
		{rawHost: "example:notaport", wantHost: "example:notaport"},
	}

	for _, tc := range cases {
		host, port, hasPort := splitHostPort(tc.rawHost)
		if host != tc.wantHost || port != tc.wantPort || hasPort != tc.wantHas {
			t.Errorf("splitHostPort(%q) = %q, %q, %v; want %q, %q, %v",
				tc.rawHost, host, port, hasPort, tc.wantHost, tc.wantPort, tc.wantHas)
		}
	}
}

func TestInstallEndpointsKeepProductionValues(t *testing.T) {
	a := &app{cfg: defaultsFor(EnvProduction)}

	r := httptest.NewRequest(http.MethodGet, "https://"+productionHost+"/vN-y_5uA/getbb.sh", nil)
	baseURL, path, tlsHost, tlsPort := a.installEndpoints(r, "vN-y_5uA")

	if baseURL != "https://"+productionHost+"/vN-y_5uA" {
		t.Errorf("baseURL = %q", baseURL)
	}
	if path != "/vN-y_5uA" {
		t.Errorf("path = %q", path)
	}
	if tlsHost != productionHost {
		t.Errorf("tlsHost = %q", tlsHost)
	}
	if tlsPort != "443" {
		t.Errorf("tlsPort = %q", tlsPort)
	}
}

func TestInstallEndpointsFollowLocalDevelopmentListeners(t *testing.T) {
	a := &app{cfg: defaultsFor(EnvDevelopment)}

	t.Run("plain http listener", func(t *testing.T) {
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/getbb.sh", nil)
		baseURL, _, tlsHost, tlsPort := a.installEndpoints(r, "vN-y_5uA")

		if baseURL != "http://localhost:8081/vN-y_5uA" {
			t.Errorf("baseURL = %q, want the http listener the request arrived on", baseURL)
		}
		// The openssl method always speaks TLS, so it has to be pointed at the
		// HTTPS listener instead of the http one.
		if tlsHost != "localhost" || tlsPort != defaultDevHTTPSPort {
			t.Errorf("openssl endpoint = %s:%s, want localhost:%s", tlsHost, tlsPort, defaultDevHTTPSPort)
		}
	})

	t.Run("https listener", func(t *testing.T) {
		r := httptest.NewRequest(http.MethodGet, "https://localhost:8443/vN-y_5uA/getbb.sh", nil)
		r.TLS = &tls.ConnectionState{}
		baseURL, _, tlsHost, tlsPort := a.installEndpoints(r, "vN-y_5uA")

		if baseURL != "https://localhost:8443/vN-y_5uA" {
			t.Errorf("baseURL = %q", baseURL)
		}
		if tlsHost != "localhost" || tlsPort != "8443" {
			t.Errorf("openssl endpoint = %s:%s, want localhost:8443", tlsHost, tlsPort)
		}
	})
}

func TestInstallEndpointsHonourNonStandardProductionPorts(t *testing.T) {
	a := &app{cfg: defaultsFor(EnvProduction)}

	r := httptest.NewRequest(http.MethodGet, "https://staging.example.invalid:8443/vN-y_5uA/getbb.sh", nil)
	_, _, tlsHost, tlsPort := a.installEndpoints(r, "vN-y_5uA")

	if tlsHost != "staging.example.invalid" || tlsPort != "8443" {
		t.Errorf("openssl endpoint = %s:%s", tlsHost, tlsPort)
	}
}

func TestSafeShellValueDropsAnythingThatCouldBreakOutOfQuotes(t *testing.T) {
	const dangerous = "http://localhost:8081/$(id); rm -rf /"

	got := safeShellValue(dangerous)
	if strings.ContainsAny(got, "'$`() \t\n;|&\"\\") {
		t.Errorf("safeShellValue(%q) = %q, dangerous characters survived", dangerous, got)
	}
	if want := "http://localhost:8081/idrm-rf/"; got != want {
		t.Errorf("safeShellValue(%q) = %q, want %q", dangerous, got, want)
	}
}

func TestInjectAfterShebang(t *testing.T) {
	definitions := "PRIMARY_COLOR='a'\nAVATAR='true'"

	withShebang := injectAfterShebang("#!/bin/bash\nrest\n", definitions)
	lines := strings.Split(withShebang, "\n")
	if lines[0] != "#!/bin/bash" {
		t.Errorf("shebang is no longer the first line: %q", withShebang)
	}
	if lines[1] != "PRIMARY_COLOR='a'" {
		t.Errorf("definitions were not injected below the shebang: %q", withShebang)
	}
	if !strings.HasSuffix(withShebang, "rest\n") {
		t.Errorf("original content was lost: %q", withShebang)
	}

	withoutShebang := injectAfterShebang("no shebang here\n", definitions)
	if !strings.HasPrefix(withoutShebang, definitions) {
		t.Errorf("definitions were not prepended: %q", withoutShebang)
	}
}

func TestResolveRepoRelativePath(t *testing.T) {
	cases := []struct{ requested, want string }{
		{requested: "prompt/bb.sh", want: "prompt/bb.sh"},
		// The download script asks for "/.inputrc"; the leading separator has to
		// stay inside the checkout instead of being rejected.
		{requested: "/.inputrc", want: ".inputrc"},
		{requested: "//.inputrc", want: ".inputrc"},
		{requested: "./prompt/../prompt/bb.sh", want: "prompt/bb.sh"},
		{requested: "../../etc/passwd", want: "etc/passwd"},
	}

	for _, tc := range cases {
		if got, err := resolveRepoRelativePath(tc.requested); err != nil || got != tc.want {
			t.Errorf("resolveRepoRelativePath(%q) = %q, %v; want %q", tc.requested, got, err, tc.want)
		}
	}

	for _, requested := range []string{"/", ""} {
		if _, err := resolveRepoRelativePath(requested); err == nil {
			t.Errorf("resolveRepoRelativePath(%q) unexpectedly succeeded", requested)
		}
	}
}

func TestServeGetBbScriptPointsAtTheServingListener(t *testing.T) {
	script := "#!/bin/bash\n" +
		"BB_BASE_URL=\"${BB_BASE_URL:-https://git.cz0.cz/czoczo/BetterBash/raw/branch/master}\"\n" +
		"BB_PATH=\"${BB_PATH:-/czoczo/BetterBash/raw/branch/master}\"\n" +
		"BB_TLS_HOST=\"${BB_TLS_HOST:-git.cz0.cz}\"\n" +
		"BB_TLS_PORT=\"${BB_TLS_PORT:-443}\"\n" +
		"echo download from $BB_BASE_URL over $BB_TLS_HOST:$BB_TLS_PORT\n"

	t.Run("production", func(t *testing.T) {
		a := newTestApp(t, defaultsFor(EnvProduction), map[string]string{getBbPath: script})

		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "https://"+productionHost+"/vN-y_5uA/getbb.sh", nil)
		a.mainRouter(rec, r)

		body := rec.Body.String()
		for _, want := range []string{
			"BB_BASE_URL='https://" + productionHost + "/vN-y_5uA'",
			"BB_PATH='/vN-y_5uA'",
			"BB_TLS_HOST='" + productionHost + "'",
			"BB_TLS_PORT='443'",
		} {
			if !strings.Contains(body, want) {
				t.Errorf("served script is missing %s\n%s", want, body)
			}
		}
		if strings.Contains(body, "git.cz0.cz") {
			t.Errorf("served script still contains the hardcoded production host\n%s", body)
		}
	})

	t.Run("development", func(t *testing.T) {
		a := newTestApp(t, defaultsFor(EnvDevelopment), map[string]string{getBbPath: script})

		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/getbb.sh", nil)
		a.mainRouter(rec, r)

		body := rec.Body.String()
		for _, want := range []string{
			"BB_BASE_URL='http://localhost:8081/vN-y_5uA'",
			"BB_TLS_HOST='localhost'",
			"BB_TLS_PORT='" + defaultDevHTTPSPort + "'",
		} {
			if !strings.Contains(body, want) {
				t.Errorf("served script is missing %s\n%s", want, body)
			}
		}
	})
}

// Clients that send the request themselves (the openssl method) close the
// connection instead of relying on keep alive, which makes Go chunk any response
// it cannot size up front. Chunk markers piped into bash are syntax errors, so
// the download script always has to be served with a Content-Length.
func TestDownloadScriptIsServedWithItsLength(t *testing.T) {
	padding := strings.Repeat("# padding to push the body past the write buffer\n", 400)
	a := newTestApp(t, defaultsFor(EnvDevelopment), map[string]string{
		getBbPath: "#!/bin/bash\n" + padding,
	})

	server := httptest.NewServer(a.handler())
	defer server.Close()

	resp, err := http.Get(server.URL + "/vN-y_5uA/getbb.sh")
	if err != nil {
		t.Fatalf("GET getbb.sh: %v", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("failed to read the response: %v", err)
	}
	if len(resp.TransferEncoding) != 0 {
		t.Errorf("Transfer-Encoding = %v, want the body to be length delimited", resp.TransferEncoding)
	}
	if resp.ContentLength != int64(len(body)) {
		t.Errorf("Content-Length = %d, body is %d bytes", resp.ContentLength, len(body))
	}
}

func TestServeBbScriptInjectsThemeBelowShebang(t *testing.T) {
	a := newTestApp(t, defaultsFor(EnvDevelopment), map[string]string{
		bbShellPath: "#!/bin/bash\n# prompt\n",
	})

	rec := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/prompt/bb.sh", nil)
	a.mainRouter(rec, r)

	body := rec.Body.String()
	lines := strings.Split(body, "\n")
	if lines[0] != "#!/bin/bash" {
		t.Errorf("shebang is no longer first:\n%s", body)
	}
	if !strings.HasPrefix(lines[1], "PRIMARY_COLOR=") {
		t.Errorf("theme was not injected:\n%s", body)
	}
	if !strings.Contains(body, "# prompt") {
		t.Errorf("original script was lost:\n%s", body)
	}
}

func TestServeServesPlainRepositoryFiles(t *testing.T) {
	a := newTestApp(t, defaultsFor(EnvDevelopment), map[string]string{".inputrc": "## BetterBash\n"})

	// The download script asks for ".inputrc" and older ones used "/.inputrc".
	for _, requested := range []string{".inputrc", "/.inputrc"} {
		rec := httptest.NewRecorder()
		r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/"+requested, nil)
		a.mainRouter(rec, r)

		if rec.Code != http.StatusOK {
			t.Errorf("GET %s -> %d: %s", requested, rec.Code, rec.Body.String())
		}
		if !strings.Contains(rec.Body.String(), "BetterBash") {
			t.Errorf("GET %s returned %q", requested, rec.Body.String())
		}
	}
}

func TestServeRejectsPathsOutsideOfTheCheckout(t *testing.T) {
	a := newTestApp(t, defaultsFor(EnvDevelopment), map[string]string{"prompt/bb.sh": "#!/bin/bash\n"})

	rec := httptest.NewRecorder()
	r := httptest.NewRequest(http.MethodGet, "http://localhost:8081/vN-y_5uA/../../../secret", nil)
	// httptest.NewRequest refuses to build a request for a raw "../" path, the
	// way a real client reaches this handler.
	r.URL.Path = "/vN-y_5uA/../../../secret"
	a.mainRouter(rec, r)

	if rec.Code == http.StatusOK && strings.Contains(rec.Body.String(), "root:") {
		t.Fatalf("served a file from outside the checkout:\n%s", rec.Body.String())
	}
}
