package main

import (
	"errors"
	"log"
	"net/http"
	"os"
)

func main() {
	cfg, err := LoadConfig()
	if err != nil {
		log.Fatalf("❌ %v\n", err)
	}

	log.Printf("⚙️  BetterBash backend running in %s mode: %s", cfg.Env, cfg)

	if err := setupRepo(cfg); err != nil {
		log.Fatalf("❌ Failed to setup repository: %s\n", err)
	}

	application := &app{cfg: cfg}
	server := &http.Server{Addr: cfg.HTTPAddr(), Handler: application.handler()}

	if cfg.TLS.Enabled {
		go serveHTTPS(cfg)
	}

	logStartupEndpoints(cfg)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("❌ Failed to start server: %s\n", err)
	}
}

// serveHTTPS runs the HTTPS listener. In development it exists so the openssl
// installation method, which always speaks TLS, can be tried out locally.
func serveHTTPS(cfg *Config) {
	tlsConfig, err := cfg.TLSConfig()
	if err != nil {
		log.Printf("❌ HTTPS listener disabled: %v", err)
		return
	}

	application := &app{cfg: cfg}
	server := &http.Server{Addr: cfg.HTTPSAddr(), TLSConfig: tlsConfig, Handler: application.handler()}

	log.Printf("🔒 HTTPS listening on %s", cfg.HTTPSAddr())
	if err := server.ListenAndServeTLS("", ""); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Printf("❌ Failed to start HTTPS server: %v", err)
	}
}

func logStartupEndpoints(cfg *Config) {
	httpBase := "http://localhost:" + cfg.Port

	log.Printf("HTTP listening on %s", cfg.HTTPAddr())
	if cfg.Repo.LocalCheckout {
		log.Printf("Git Repo URL: (none, serving the working copy at %s)", cfg.Repo.Path)
	} else {
		log.Printf("Git Repo URL: %s", cfg.Repo.URL)
		log.Printf("Local Repo Path: %s", cfg.Repo.Path)
	}
	log.Printf("Special file for color injection: %s", bbShellPath)
	log.Printf("Endpoints:")
	log.Printf("  GET /<encoded_color_data>         - Show color definitions")
	log.Printf("  GET /<encoded_color_data>/<path> - Serve file from repo (e.g., /VcrS_H8A/removebb.sh)")
	log.Printf("                                    Special: /<encoded_color_data>/%s for dynamic colors", bbShellPath)
	log.Printf("  GET /%s                             - Show color definitions of a randomly generated theme", randPathKeyword)
	log.Printf("  GET /%s/<path>                      - Same as /<encoded_color_data>/<path>, but with a randomly generated", randPathKeyword)
	log.Printf("                                    theme on every request (e.g. /%s/%s install, /%s/removebb.sh uninstall)", randPathKeyword, getBbPath, randPathKeyword)
	log.Printf("  GET /reload                       - Pull latest from git %s branch", cfg.Repo.Branch)
	log.Printf("  GET /stats                        - Show request count")
	log.Printf("  GET /metrics                      - Prometheus metrics endpoint")
	log.Printf("  GET /                             - Redirect to %s", cfg.RedirectURL)

	if cfg.IsDevelopment() {
		log.Printf("Development install commands (see also ./dev.sh in the repository root):")
		log.Printf("  curl    curl -sL %s/<code>/%s | bash -s curl && . ~/.bashrc", httpBase, getBbPath)
		log.Printf("  wget    wget -q -O - %s/<code>/%s | bash -s wget && . ~/.bashrc", httpBase, getBbPath)
		if cfg.TLS.Enabled {
			log.Printf("  openssl echo -e \"GET /<code>/%s HTTP/1.1\\r\\nHost: localhost:%s\\r\\nConnection: close\\r\\n\\r\\n\" "+
				"| openssl s_client -quiet -connect localhost:%s 2>/dev/null | sed '1,/^\\r$/d' | bash -s openssl && . ~/.bashrc",
				getBbPath, cfg.TLS.Port, cfg.TLS.Port)
		}
	}

	if _, err := os.Stat(cfg.Repo.Path); err != nil {
		log.Printf("⚠️  Repository path %s is not readable: %v", cfg.Repo.Path, err)
	}
}
