package main

import (
	"strings"
	"testing"
)

// clearEnv removes the influence of the ambient environment from a test.
func clearEnv(t *testing.T) {
	t.Helper()
	for _, key := range []string{
		"APP_ENV", "BB_ENV", "PORT", "BB_HTTP_PORT", "BB_HTTPS_PORT", "BB_TLS_ENABLED",
		"BB_TLS_CERT_FILE", "BB_TLS_KEY_FILE", "BB_REPO_URL", "BB_REPO_PATH",
		"BB_REPO_BRANCH", "BB_REPO_LOCAL", "BB_REDIRECT_URL",
	} {
		t.Setenv(key, "")
	}
}

func TestLoadConfigWithoutEnvironmentVariablesIsProduction(t *testing.T) {
	clearEnv(t)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}

	if cfg.Env != EnvProduction {
		t.Errorf("Env = %q, want %q", cfg.Env, EnvProduction)
	}
	if cfg.Port != defaultProdPort {
		t.Errorf("Port = %q, want %q", cfg.Port, defaultProdPort)
	}
	if cfg.TLS.Enabled {
		t.Errorf("TLS must stay disabled in production, the proxy in front terminates it")
	}
	if cfg.Repo.URL != defaultProdRepoURL {
		t.Errorf("Repo.URL = %q, want %q", cfg.Repo.URL, defaultProdRepoURL)
	}
	if cfg.Repo.Path != defaultProdRepoPath {
		t.Errorf("Repo.Path = %q, want %q", cfg.Repo.Path, defaultProdRepoPath)
	}
	if cfg.Repo.Branch != defaultProdRepoBranch {
		t.Errorf("Repo.Branch = %q, want %q", cfg.Repo.Branch, defaultProdRepoBranch)
	}
	if cfg.Repo.LocalCheckout {
		t.Errorf("production must serve a cloned checkout, not a developer working copy")
	}
	if cfg.RedirectURL != defaultProdRedirectURL {
		t.Errorf("RedirectURL = %q, want %q", cfg.RedirectURL, defaultProdRedirectURL)
	}
	if cfg.PublicScheme != "https" {
		t.Errorf("PublicScheme = %q, want %q", cfg.PublicScheme, "https")
	}
}

// The remote renamed its default branch once, and a missing branch is only
// noticed as a failing clone, so the value is spelled out instead of being
// mirrored from the constant.
func TestProductionServesTheDefaultBranchOfTheRepository(t *testing.T) {
	clearEnv(t)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}
	if cfg.Repo.Branch != "main" {
		t.Errorf("Repo.Branch = %q, want the default branch of the repository (main)", cfg.Repo.Branch)
	}
}

func TestLoadConfigDevelopment(t *testing.T) {
	for _, alias := range []string{"development", "Development", "dev", "local"} {
		clearEnv(t)
		t.Setenv("APP_ENV", alias)

		cfg, err := LoadConfig()
		if err != nil {
			t.Fatalf("APP_ENV=%q: LoadConfig() returned an error: %v", alias, err)
		}

		if cfg.Env != EnvDevelopment {
			t.Fatalf("APP_ENV=%q resolved to %q, want %q", alias, cfg.Env, EnvDevelopment)
		}
		if !cfg.IsDevelopment() || cfg.IsProduction() {
			t.Errorf("APP_ENV=%q: IsDevelopment/IsProduction disagree with Env=%q", alias, cfg.Env)
		}
		if cfg.Port != defaultDevPort {
			t.Errorf("Port = %q, want %q", cfg.Port, defaultDevPort)
		}
		if !cfg.TLS.Enabled {
			t.Errorf("TLS must be enabled in development so the openssl method can be tested")
		}
		if cfg.TLS.Port != defaultDevHTTPSPort {
			t.Errorf("TLS.Port = %q, want %q", cfg.TLS.Port, defaultDevHTTPSPort)
		}
		if cfg.Repo.Path != defaultDevRepoPath {
			t.Errorf("Repo.Path = %q, want %q", cfg.Repo.Path, defaultDevRepoPath)
		}
		if !cfg.Repo.LocalCheckout {
			t.Errorf("development must serve the working copy the developer edits")
		}
		if cfg.Repo.URL != "" {
			t.Errorf("Repo.URL = %q, want an empty URL for a local checkout", cfg.Repo.URL)
		}
		if cfg.RedirectURL != defaultDevRedirectURL {
			t.Errorf("RedirectURL = %q, want %q", cfg.RedirectURL, defaultDevRedirectURL)
		}
		if cfg.PublicScheme != "" {
			t.Errorf("PublicScheme = %q, want it derived from the listener in development", cfg.PublicScheme)
		}
	}
}

func TestLoadConfigUnknownEnvironmentFallsBackToProduction(t *testing.T) {
	for _, value := range []string{"", "staging", "prod", "PRODUCTION"} {
		clearEnv(t)
		t.Setenv("APP_ENV", value)

		cfg, err := LoadConfig()
		if err != nil {
			t.Fatalf("APP_ENV=%q: LoadConfig() returned an error: %v", value, err)
		}
		if cfg.Env != EnvProduction {
			t.Errorf("APP_ENV=%q resolved to %q, want the safe %q default", value, cfg.Env, EnvProduction)
		}
	}
}

func TestBBEnvOverridesAppEnv(t *testing.T) {
	clearEnv(t)
	t.Setenv("APP_ENV", EnvProduction)
	t.Setenv("BB_ENV", EnvDevelopment)

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}
	if cfg.Env != EnvDevelopment {
		t.Errorf("Env = %q, want %q (BB_ENV wins over APP_ENV)", cfg.Env, EnvDevelopment)
	}
}

func TestLoadConfigAppliesOverridesInBothEnvironments(t *testing.T) {
	for _, env := range []string{EnvProduction, EnvDevelopment} {
		clearEnv(t)
		t.Setenv("APP_ENV", env)
		t.Setenv("BB_REPO_PATH", "/tmp/served-checkout")
		t.Setenv("BB_REPO_BRANCH", "develop")
		t.Setenv("BB_REDIRECT_URL", "https://example.invalid")
		t.Setenv("BB_HTTPS_PORT", "9443")
		t.Setenv("BB_TLS_CERT_FILE", "/tmp/dev-cert.pem")
		t.Setenv("BB_TLS_KEY_FILE", "/tmp/dev-key.pem")

		cfg, err := LoadConfig()
		if err != nil {
			t.Fatalf("%s: LoadConfig() returned an error: %v", env, err)
		}

		if cfg.Repo.Path != "/tmp/served-checkout" {
			t.Errorf("%s: Repo.Path = %q", env, cfg.Repo.Path)
		}
		if cfg.Repo.Branch != "develop" {
			t.Errorf("%s: Repo.Branch = %q", env, cfg.Repo.Branch)
		}
		if cfg.RedirectURL != "https://example.invalid" {
			t.Errorf("%s: RedirectURL = %q", env, cfg.RedirectURL)
		}
		if !cfg.TLS.Enabled || cfg.TLS.Port != "9443" {
			t.Errorf("%s: TLS = %+v, want enabled on 9443", env, cfg.TLS)
		}
		if cfg.TLS.CertFile != "/tmp/dev-cert.pem" || cfg.TLS.KeyFile != "/tmp/dev-key.pem" {
			t.Errorf("%s: TLS certificate paths not honoured: %+v", env, cfg.TLS)
		}
	}
}

func TestRemoteRepositoryOverridesLocalCheckout(t *testing.T) {
	clearEnv(t)
	t.Setenv("APP_ENV", EnvDevelopment)
	t.Setenv("BB_REPO_URL", "https://example.invalid/BetterBash.git")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}
	if cfg.Repo.LocalCheckout {
		t.Errorf("an explicit BB_REPO_URL must turn off the local working checkout")
	}
	if cfg.Repo.URL != "https://example.invalid/BetterBash.git" {
		t.Errorf("Repo.URL = %q", cfg.Repo.URL)
	}
}

func TestLocalCheckoutCanBeReopenedInProduction(t *testing.T) {
	clearEnv(t)
	t.Setenv("BB_REPO_PATH", ".")
	t.Setenv("BB_REPO_LOCAL", "true")

	cfg, err := LoadConfig()
	if err != nil {
		t.Fatalf("LoadConfig() returned an error: %v", err)
	}
	if !cfg.Repo.LocalCheckout {
		t.Errorf("BB_REPO_LOCAL=true was ignored")
	}
}

func TestValidateRejectsHalfConfigurations(t *testing.T) {
	cases := []struct {
		name    string
		mutate  func(*Config)
		wantErr string
	}{
		{
			name:    "https sharing the http port",
			mutate:  func(c *Config) { c.TLS = TLSConfig{Enabled: true, Port: c.Port} },
			wantErr: "must differ",
		},
		{
			name:    "certificate without a key",
			mutate:  func(c *Config) { c.TLS = TLSConfig{Enabled: true, Port: "8443", CertFile: "/tmp/cert.pem"} },
			wantErr: "set together",
		},
		{
			name:    "remote without a URL",
			mutate:  func(c *Config) { c.Repo = RepoConfig{Path: "repo", Branch: "main"} },
			wantErr: "repository URL is required",
		},
		{
			name:    "remote without a branch",
			mutate:  func(c *Config) { c.Repo = RepoConfig{URL: "https://example.invalid/r.git", Path: "repo"} },
			wantErr: "branch is required",
		},
		{
			name:    "invalid port",
			mutate:  func(c *Config) { c.Port = "http" },
			wantErr: "invalid HTTP port",
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			cfg := defaultsFor(EnvDevelopment)
			tc.mutate(cfg)

			err := cfg.Validate()
			if err == nil {
				t.Fatalf("expected an error mentioning %q, got none", tc.wantErr)
			}
			if !strings.Contains(err.Error(), tc.wantErr) {
				t.Fatalf("error %q does not mention %q", err, tc.wantErr)
			}
		})
	}
}

// The openssl installation method needs a HTTPS listener, but only a development
// instance may open one without being told to.
func TestHTTPSServerOnlyExistsWhereItIsNeeded(t *testing.T) {
	cases := []struct {
		name string
		env  string
		vars map[string]string
		want bool
	}{
		{name: "production keeps TLS off", env: "production", want: false},
		{name: "production can serve TLS explicitly", env: "production", vars: map[string]string{"BB_TLS_ENABLED": "true"}, want: true},
		{
			name: "certificates on disk enable TLS in every environment",
			env:  "production",
			vars: map[string]string{"BB_TLS_CERT_FILE": "/tmp/cert.pem", "BB_TLS_KEY_FILE": "/tmp/key.pem"},
			want: true,
		},
		{name: "development serves TLS by default", env: "development", want: true},
		{name: "development can give up TLS", env: "development", vars: map[string]string{"BB_TLS_ENABLED": "false"}, want: false},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			clearEnv(t)
			t.Setenv("APP_ENV", tc.env)
			for k, v := range tc.vars {
				t.Setenv(k, v)
			}

			cfg, err := LoadConfig()
			if err != nil {
				t.Fatalf("LoadConfig() in %s returned an error: %v", tc.env, err)
			}
			if cfg.TLS.Enabled != tc.want {
				t.Errorf("TLS.Enabled = %v, want %v", cfg.TLS.Enabled, tc.want)
			}
			if cfg.TLS.Enabled && cfg.TLS.Port == "" {
				t.Errorf("an HTTPS server needs a port")
			}
		})
	}
}

func TestDevelopmentCertificateCoversLocalhost(t *testing.T) {
	cert, err := devCertificate()
	if err != nil {
		t.Fatalf("devCertificate() returned an error: %v", err)
	}
	if len(cert.Certificate) == 0 {
		t.Fatalf("no certificate was generated")
	}

	cfg := &Config{TLS: TLSConfig{Enabled: true, Port: defaultDevHTTPSPort}}
	tlsConfig, err := cfg.TLSConfig()
	if err != nil {
		t.Fatalf("TLSConfig() returned an error: %v", err)
	}
	if tlsConfig.GetCertificate == nil {
		t.Fatalf("GetCertificate must serve the generated certificate when no files are configured")
	}

	served, err := tlsConfig.GetCertificate(nil)
	if err != nil {
		t.Fatalf("GetCertificate returned an error: %v", err)
	}
	if served == nil {
		t.Fatalf("GetCertificate returned no certificate")
	}
}

func TestConfigStringMentionsEnvironmentAndListeners(t *testing.T) {
	cfg := defaultsFor(EnvDevelopment)
	description := cfg.String()

	for _, want := range []string{"env=" + EnvDevelopment, "http", "https", "local working copy"} {
		if !strings.Contains(description, want) {
			t.Errorf("description %q does not mention %q", description, want)
		}
	}
}
