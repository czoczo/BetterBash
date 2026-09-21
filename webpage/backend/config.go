package main

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"fmt"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// Environment names accepted by APP_ENV. Anything unknown falls back to
// production, so a missing variable can never expose a development setup.
const (
	EnvProduction  = "production"
	EnvDevelopment = "development"

	// envAliases allow "dev" and "local" to be used interchangeably with "development".
	envAliasDev   = "dev"
	envAliasLocal = "local"
)

// Production defaults are the values the service has always run with. Changing
// them means changing the deployed endpoints, so they are intentionally not
// reachable through a typo in an environment variable name.
const (
	defaultProdPort        = "8081"
	defaultProdHTTPSPort   = "8443"
	defaultProdRedirectURL = "https://betterbash.cz0.cz"
	defaultProdRepoURL     = "https://github.com/czoczo/BetterBash"
	defaultProdRepoPath    = "BetterBashRepo"
	// The default branch of the repository. It was renamed from master once, and
	// cloning then fails with "couldn't find remote ref", so it is called out in
	// the clone error and can be overridden with BB_REPO_BRANCH.
	defaultProdRepoBranch = "main"

	// Development defaults. The backend runs from webpage/backend, so "../.."
	// points at the working copy the developer is editing.
	defaultDevPort        = "8081"
	defaultDevHTTPSPort   = "8443"
	defaultDevRepoPath    = "../.."
	defaultDevRepoBranch  = "master"
	defaultDevRedirectURL = "http://localhost:5173"
)

// RepoConfig describes where the files served by the backend come from.
type RepoConfig struct {
	// URL is the git remote cloned into Path and pulled on /reload.
	// It is unused when LocalCheckout is true.
	URL string
	// Path is the directory every served file is read from. Relative paths are
	// resolved against the working directory of the process.
	Path string
	// Branch is the remote branch /reload resets Path onto.
	Branch string
	// LocalCheckout marks Path as a working tree maintained by a developer.
	// It is never cloned into, fetched from or reset, so uncommitted changes can
	// be exercised against the running backend.
	LocalCheckout bool
}

// TLSConfig controls the HTTPS listener. Production terminates TLS in front of
// the container, development serves its own throwaway certificate so that the
// openssl installation method can be exercised locally.
type TLSConfig struct {
	Enabled  bool
	Port     string
	CertFile string
	KeyFile  string
}

// Config is the full, environment resolved configuration of one backend
// process. Load it once with LoadConfig and pass it around explicitly.
type Config struct {
	// Env is EnvProduction or EnvDevelopment.
	Env string
	// Port is the plain HTTP listener.
	Port string
	// TLS is the HTTPS listener configuration.
	TLS TLSConfig
	// Repo is the git checkout the files are served from.
	Repo RepoConfig
	// RedirectURL is the target of the root path ("/").
	RedirectURL string
	// PublicScheme is the scheme the download script has to use for curl and
	// wget. Empty means "follow the listener that served the request", which is
	// what development needs. Production terminates TLS in front of the
	// container, so the request itself always arrives as plain HTTP and https
	// has to be assumed.
	PublicScheme string
}

// IsDevelopment reports whether the process runs in development mode.
func (c *Config) IsDevelopment() bool { return c.Env == EnvDevelopment }

// IsProduction reports whether the process runs in production mode.
func (c *Config) IsProduction() bool { return c.Env == EnvProduction }

// environmentName normalises APP_ENV (and its aliases) to EnvProduction or
// EnvDevelopment. Unknown or empty values mean production.
func environmentName(raw string) string {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case EnvDevelopment, envAliasDev, envAliasLocal:
		return EnvDevelopment
	default:
		return EnvProduction
	}
}

// getenv reads an environment variable, falling back to def when unset or empty.
func getenv(key, def string) string {
	if v, ok := os.LookupEnv(key); ok && strings.TrimSpace(v) != "" {
		return strings.TrimSpace(v)
	}
	return def
}

// getbool reads a boolean-ish environment variable ("1", "true", "yes", "on").
func getbool(key string, def bool) bool {
	raw := getenv(key, "")
	if raw == "" {
		return def
	}
	switch strings.ToLower(raw) {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return def
	}
}

// defaultsFor builds the environment specific baseline every option of which
// can still be overridden individually (see applyEnvOverrides).
func defaultsFor(env string) *Config {
	if env == EnvDevelopment {
		return &Config{
			Env:  EnvDevelopment,
			Port: getenv("BB_HTTP_PORT", getenv("PORT", defaultDevPort)),
			TLS:  TLSConfig{Enabled: getbool("BB_TLS_ENABLED", true), Port: getenv("BB_HTTPS_PORT", defaultDevHTTPSPort)},
			// The branch only matters when BB_REPO_URL points at a remote instead of
			// at the developer's working copy.
			Repo:         RepoConfig{Path: getenv("BB_REPO_PATH", defaultDevRepoPath), Branch: defaultDevRepoBranch, LocalCheckout: true},
			RedirectURL:  getenv("BB_REDIRECT_URL", defaultDevRedirectURL),
			PublicScheme: "",
		}
	}

	return &Config{
		Env:          EnvProduction,
		Port:         getenv("PORT", defaultProdPort),
		TLS:          TLSConfig{Enabled: false, Port: getenv("BB_HTTPS_PORT", defaultProdHTTPSPort)},
		Repo:         RepoConfig{URL: defaultProdRepoURL, Path: defaultProdRepoPath, Branch: defaultProdRepoBranch},
		RedirectURL:  getenv("BB_REDIRECT_URL", defaultProdRedirectURL),
		PublicScheme: "https",
	}
}

// applyEnvOverrides layers explicit environment variables on top of the
// defaults. It exists so that both environments can be pointed anywhere without
// recompiling, e.g. a staging instance cloning another branch.
func (c *Config) applyEnvOverrides() {
	if v := getenv("BB_REPO_URL", ""); v != "" {
		c.Repo.URL = v
		// An explicit remote wins over the local working checkout.
		c.Repo.LocalCheckout = false
	}
	if v := getenv("BB_REPO_BRANCH", ""); v != "" {
		c.Repo.Branch = v
	}
	if v := getenv("BB_REPO_PATH", ""); v != "" {
		c.Repo.Path = v
	}
	if _, set := os.LookupEnv("BB_REPO_LOCAL"); set {
		c.Repo.LocalCheckout = getbool("BB_REPO_LOCAL", c.Repo.LocalCheckout)
	}

	// A certificate on disk is valid in both environments; without one,
	// development falls back to an ephemeral self-signed certificate.
	c.TLS.CertFile = getenv("BB_TLS_CERT_FILE", "")
	c.TLS.KeyFile = getenv("BB_TLS_KEY_FILE", "")
	certificatesGiven := c.TLS.CertFile != "" || c.TLS.KeyFile != ""
	if certificatesGiven {
		c.TLS.Enabled = true
	}
	if !certificatesGiven && c.IsProduction() {
		// Production terminates TLS in front of the container, so its own HTTPS
		// listener stays off unless it is asked for explicitly.
		c.TLS.Enabled = getbool("BB_TLS_ENABLED", false)
	}
}

// Validate rejects configurations that would start a half working server.
func (c *Config) Validate() error {
	if _, err := strconv.Atoi(c.Port); err != nil || c.Port == "" {
		return fmt.Errorf("invalid HTTP port %q: %v", c.Port, err)
	}

	if !c.Repo.LocalCheckout && strings.TrimSpace(c.Repo.URL) == "" {
		return fmt.Errorf("repository URL is required unless the repository path is a local checkout")
	}
	if !c.Repo.LocalCheckout && strings.TrimSpace(c.Repo.Branch) == "" {
		return fmt.Errorf("repository branch is required when the repository is cloned from a remote")
	}
	if strings.TrimSpace(c.Repo.Path) == "" {
		return fmt.Errorf("repository path is required")
	}

	if c.TLS.Enabled {
		if _, err := strconv.Atoi(c.TLS.Port); err != nil {
			return fmt.Errorf("invalid HTTPS port %q: %v", c.TLS.Port, err)
		}
		if c.TLS.Port == c.Port {
			return fmt.Errorf("HTTPS port %s must differ from the HTTP port %s", c.TLS.Port, c.Port)
		}
		if (c.TLS.CertFile == "") != (c.TLS.KeyFile == "") {
			return fmt.Errorf("BB_TLS_CERT_FILE and BB_TLS_KEY_FILE must be set together")
		}
	}

	if strings.TrimSpace(c.RedirectURL) == "" {
		return fmt.Errorf("redirect URL is required")
	}

	return nil
}

// AbsRepoPath resolves Repo.Path against the working directory, so that served
// paths can be checked against it without any symlink surprises.
func (c *Config) AbsRepoPath() (string, error) {
	abs, err := filepath.Abs(c.Repo.Path)
	if err != nil {
		return "", fmt.Errorf("failed to resolve repository path %q: %w", c.Repo.Path, err)
	}
	return abs, nil
}

// HTTPAddr is the address the plain HTTP listener binds to.
func (c *Config) HTTPAddr() string { return ":" + c.Port }

// HTTPSAddr is the address the HTTPS listener binds to, empty when disabled.
func (c *Config) HTTPSAddr() string {
	if !c.TLS.Enabled {
		return ""
	}
	return ":" + c.TLS.Port
}

// String renders a short, log friendly summary of the configuration.
func (c *Config) String() string {
	repo := fmt.Sprintf("path=%s", c.Repo.Path)
	if c.Repo.LocalCheckout {
		repo += " (local working copy, never pulled or reset)"
	} else {
		repo += fmt.Sprintf(" (remote %s, branch %s)", c.Repo.URL, c.Repo.Branch)
	}

	listeners := "http://" + c.HTTPAddr()
	if c.TLS.Enabled {
		note := "self-signed"
		if c.TLS.CertFile != "" {
			note = c.TLS.CertFile
		}
		listeners += fmt.Sprintf(", https://%s (%s)", c.HTTPSAddr(), note)
	}

	return fmt.Sprintf("env=%s listeners=[%s] repo=%s redirect=%s",
		c.Env, listeners, repo, c.RedirectURL)
}

// LoadConfig resolves the configuration for the environment named in APP_ENV
// (BB_ENV wins when set), applies the overrides and validates the result.
func LoadConfig() (*Config, error) {
	env := environmentName(getenv("BB_ENV", getenv("APP_ENV", EnvProduction)))

	cfg := defaultsFor(env)
	cfg.applyEnvOverrides()

	if err := cfg.Validate(); err != nil {
		return nil, fmt.Errorf("invalid configuration for %s: %w", env, err)
	}
	return cfg, nil
}

// devCertificate builds an in-memory self-signed certificate for localhost. It
// is only used by the development HTTPS listener, so that the openssl
// installation method (which always speaks TLS) can be tested locally. The
// certificate is thrown away with the process.
func devCertificate() (*tls.Certificate, error) {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("failed to generate development key: %w", err)
	}

	notBefore := time.Now().Add(-time.Hour)
	notAfter := notBefore.Add(24 * 30 * time.Hour)

	serialLimit := new(big.Int).Lsh(big.NewInt(1), 128)
	serial, err := rand.Int(rand.Reader, serialLimit)
	if err != nil {
		return nil, fmt.Errorf("failed to generate certificate serial: %w", err)
	}

	dnsNames := []string{"localhost"}
	if hostname, err := os.Hostname(); err == nil && hostname != "" && hostname != "localhost" {
		dnsNames = append(dnsNames, hostname)
	}

	template := x509.Certificate{
		SerialNumber:          serial,
		Subject:               pkix.Name{CommonName: "BetterBash development", Organization: []string{"BetterBash"}},
		NotBefore:             notBefore,
		NotAfter:              notAfter,
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageCertSign,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		IsCA:                  true,
		DNSNames:              dnsNames,
		IPAddresses:           []net.IP{net.ParseIP("127.0.0.1"), net.ParseIP("::1")},
	}

	der, err := x509.CreateCertificate(rand.Reader, &template, &template, &key.PublicKey, key)
	if err != nil {
		return nil, fmt.Errorf("failed to create development certificate: %w", err)
	}

	keyDER, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		return nil, fmt.Errorf("failed to encode development key: %w", err)
	}

	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})

	cert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		return nil, fmt.Errorf("failed to load the generated development certificate: %w", err)
	}
	return &cert, nil
}

// TLSConfig returns the tls.Config for the HTTPS listener. When no certificate
// files are configured (the usual development case) an ephemeral self-signed
// certificate is generated and served through GetCertificate.
func (c *Config) TLSConfig() (*tls.Config, error) {
	base := &tls.Config{MinVersion: tls.VersionTLS12}

	if c.TLS.CertFile == "" || c.TLS.KeyFile == "" {
		cert, err := devCertificate()
		if err != nil {
			return nil, err
		}
		base.GetCertificate = func(*tls.ClientHelloInfo) (*tls.Certificate, error) { return cert, nil }
		return base, nil
	}

	cert, err := tls.LoadX509KeyPair(c.TLS.CertFile, c.TLS.KeyFile)
	if err != nil {
		return nil, fmt.Errorf("failed to load certificate %s and key %s: %w", c.TLS.CertFile, c.TLS.KeyFile, err)
	}
	base.Certificates = []tls.Certificate{cert}
	return base, nil
}
