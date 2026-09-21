package main

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

const (
	bbShellPath = "prompt/bb.sh"
	getBbPath   = "getbb.sh"
)

// Legacy placeholders shipped in the released getbb.sh. The backend revision
// that is deployed today rewrites exactly these two tokens, and so do we, which
// keeps (old backend + new script) and (new backend + old script) working during
// a rollout. They can be dropped once the BB_* variable based script is the one
// being served.
const (
	legacyHostToken = "git.cz0.cz"
	legacyPathToken = "/czoczo/BetterBash/raw/branch/master"
)

var (
	requestCounter uint64

	// Prometheus metrics
	httpRequestsTotal = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "http_requests_total",
			Help: "Total number of HTTP requests by endpoint",
		},
		[]string{"endpoint", "method", "status_code"},
	)
)

func init() {
	// Register Prometheus metrics
	prometheus.MustRegister(httpRequestsTotal)
}

func recordMetrics(endpoint, method, statusCode string) {
	httpRequestsTotal.WithLabelValues(endpoint, method, statusCode).Inc()
}

// app bundles the HTTP handlers with the configuration they serve.
type app struct {
	cfg *Config
}

// installEndpoints tells a download script served to r where to fetch the rest
// of the files from. baseURL is used by the curl and wget variants, while the
// openssl variant always needs a TLS host and port.
func (a *app) installEndpoints(r *http.Request, code string) (baseURL, path, tlsHost, tlsPort string) {
	host, port, hasPort := splitHostPort(r.Host)

	servedTLS := r.TLS != nil

	scheme := a.cfg.PublicScheme
	if scheme == "" {
		scheme = "http"
		if servedTLS {
			scheme = "https"
		}
	}

	path = "/" + code
	baseURL = fmt.Sprintf("%s://%s%s", scheme, r.Host, path)

	tlsHost = host
	switch {
	case servedTLS:
		tlsPort = port
		if tlsPort == "" {
			tlsPort = "443"
		}
	case a.cfg.TLS.Enabled:
		// Development serves plain HTTP and HTTPS side by side: the openssl
		// method has to be pointed at the HTTPS listener.
		tlsPort = a.cfg.TLS.Port
	default:
		// Production terminates TLS in front of the container.
		tlsPort = "443"
		if hasPort {
			tlsPort = port
		}
	}

	return baseURL, path, tlsHost, tlsPort
}

// splitHostPort splits an URL host ("host", "host:port", "[::1]:8080") into its
// host and port parts. The third return value reports whether a port was given.
func splitHostPort(rawHost string) (host, port string, hasPort bool) {
	host = rawHost
	if colon := strings.LastIndex(rawHost, ":"); colon != -1 {
		// A colon inside brackets is part of an IPv6 address, not a separator.
		if !strings.Contains(rawHost[colon:], "]") {
			host = rawHost[:colon]
			port = rawHost[colon+1:]
			hasPort = port != ""
		}
	}
	if _, err := net.LookupPort("tcp", port); err != nil {
		// Not a numeric port, so it was never a port to begin with.
		host, port, hasPort = rawHost, "", false
	}
	return host, port, hasPort
}

// safeShellValue keeps values interpolated into a single quoted shell assignment
// from breaking out of it. Everything generated from the URL is alphanumeric, so
// anything else is simply dropped.
func safeShellValue(value string) string {
	var sb strings.Builder
	for _, r := range value {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			sb.WriteRune(r)
		case strings.ContainsRune("._-/:+", r):
			sb.WriteRune(r)
		}
	}
	return sb.String()
}

// installConfigBlock is the snippet injected into getbb.sh. It overrides the
// production defaults baked into the script, so a download started against any
// listener (localhost included) keeps talking to that same listener.
func installConfigBlock(baseURL, path, tlsHost, tlsPort string) string {
	fields := []string{
		"BB_BASE_URL=" + "'" + safeShellValue(baseURL) + "'",
		"BB_PATH=" + "'" + safeShellValue(path) + "'",
		"BB_TLS_HOST=" + "'" + safeShellValue(tlsHost) + "'",
		"BB_TLS_PORT=" + "'" + safeShellValue(tlsPort) + "'",
	}
	return strings.Join(fields, "\n")
}

// injectAfterShebang prepends definitions to a script, keeping the shebang (if
// any) as the very first line. definitions is expected to be one assignment per
// line.
func injectAfterShebang(content, definitions string) string {
	if strings.TrimSpace(definitions) == "" {
		return content
	}

	lines := strings.SplitN(content, "\n", 2)
	firstLine := ""
	rest := ""
	if len(lines) > 0 {
		firstLine = lines[0]
	}
	if len(lines) > 1 {
		rest = lines[1]
	}

	var out strings.Builder
	if strings.HasPrefix(firstLine, "#!") {
		out.WriteString(firstLine + "\n")
		out.WriteString(definitions + "\n")
		out.WriteString(rest)
		return out.String()
	}

	// No shebang: definitions still have to come first.
	out.WriteString(definitions + "\n")
	out.WriteString(content)
	return out.String()
}

func (a *app) serveDecodedColorsOnlyHandler(w http.ResponseWriter, r *http.Request, encodedData string) {
	_, formattedOutput, _, err := decodeColorLogic(encodedData)
	if err != nil {
		recordMetrics("color_decode", r.Method, "400")
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	// The formattedOutput from decodeColorLogic is already KEY='VAL'\nKEY2='VAL2'
	// So it prints multiple lines as intended.
	fmt.Fprintln(w, formattedOutput)
	recordMetrics("color_decode", r.Method, "200")
}

// resolveRepoRelativePath turns a requested path into one relative to the
// repository root. Leading separators carry no meaning here (scripts ask for
// "/.inputrc") and parent directory references are folded away, so nothing can
// escape the checkout.
func resolveRepoRelativePath(requested string) (string, error) {
	cleaned := filepath.Clean("/" + filepath.ToSlash(requested))
	cleaned = strings.TrimPrefix(cleaned, "/")
	if cleaned == "" || cleaned == "." {
		return "", errors.New("empty file path")
	}
	return cleaned, nil
}

// serveFileHandler serves files from the repository, injecting the theme into
// bb.sh and the install endpoints into getbb.sh.
func (a *app) serveFileHandler(w http.ResponseWriter, r *http.Request, encodedData, requestedFilePath string) {
	// Note: The 'colorsMap' is not strictly needed for the new bb.sh logic,
	// as 'formattedColorDefinitions' is used directly. But decodeColorLogic provides it.
	_, formattedColorDefinitions, _, err := decodeColorLogic(encodedData)
	if err != nil {
		recordMetrics("file_serve", r.Method, "400")
		http.Error(w, fmt.Sprintf("Failed to decode colors: %v", err), http.StatusBadRequest)
		return
	}

	cleanFilePath, err := resolveRepoRelativePath(requestedFilePath)
	if err != nil {
		recordMetrics("file_serve", r.Method, "400")
		http.Error(w, "Invalid file path.", http.StatusBadRequest)
		return
	}

	absRepoPath, err := a.cfg.AbsRepoPath()
	if err != nil {
		recordMetrics("file_serve", r.Method, "500")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	fullPath := filepath.Join(absRepoPath, cleanFilePath)
	if !strings.HasPrefix(fullPath, absRepoPath+string(os.PathSeparator)) {
		recordMetrics("file_serve", r.Method, "403")
		http.Error(w, "Access to file path denied.", http.StatusForbidden)
		return
	}

	fileInfo, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		recordMetrics("file_serve", r.Method, "404")
		http.Error(w, fmt.Sprintf("File not found: %s", requestedFilePath), http.StatusNotFound)
		return
	}
	if err != nil {
		recordMetrics("file_serve", r.Method, "500")
		http.Error(w, fmt.Sprintf("Error accessing file: %v", err), http.StatusInternalServerError)
		return
	}
	if fileInfo.IsDir() {
		recordMetrics("file_serve", r.Method, "400")
		http.Error(w, fmt.Sprintf("Requested path is a directory: %s", requestedFilePath), http.StatusBadRequest)
		return
	}

	switch cleanFilePath {
	case getBbPath:
		a.serveGetBbScript(w, r, encodedData, fullPath)
	case bbShellPath:
		a.serveBbScript(w, r, formattedColorDefinitions, fullPath)
	default:
		http.ServeFile(w, r, fullPath)
		recordMetrics("file_serve", r.Method, "200")
	}
}

// serveGetBbScript hands out the download script with the endpoints of this very
// backend filled in, so that the curl, wget and openssl methods all keep talking
// to the listener that served them.
func (a *app) serveGetBbScript(w http.ResponseWriter, r *http.Request, encodedData, fullPath string) {
	originalContentBytes, err := os.ReadFile(fullPath)
	if err != nil {
		recordMetrics("file_serve", r.Method, "500")
		http.Error(w, fmt.Sprintf("Error reading %s: %v", getBbPath, err), http.StatusInternalServerError)
		return
	}

	originalContent := string(originalContentBytes)
	// Released scripts only understand the two legacy placeholders.
	originalContent = strings.Replace(originalContent, legacyHostToken, r.Host, -1)
	originalContent = strings.Replace(originalContent, legacyPathToken, "/"+encodedData, -1)
	// Current scripts read the BB_* variables, which always win.
	baseURL, path, tlsHost, tlsPort := a.installEndpoints(r, encodedData)
	originalContent = injectAfterShebang(originalContent, installConfigBlock(baseURL, path, tlsHost, tlsPort))

	// A download script is piped straight into bash. Declaring the length keeps
	// Go from chunking the response, which would otherwise leave chunk markers
	// in the script for clients that send the request themselves (openssl).
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Length", strconv.Itoa(len(originalContent)))
	fmt.Fprint(w, originalContent)
	recordMetrics("file_serve", r.Method, "200")
}

// serveBbScript hands out the prompt script with the decoded theme injected.
func (a *app) serveBbScript(w http.ResponseWriter, r *http.Request, formattedColorDefinitions, fullPath string) {
	originalContentBytes, err := os.ReadFile(fullPath)
	if err != nil {
		recordMetrics("file_serve", r.Method, "500")
		http.Error(w, fmt.Sprintf("Error reading %s: %v", bbShellPath, err), http.StatusInternalServerError)
		return
	}

	finalScript := injectAfterShebang(string(originalContentBytes), formattedColorDefinitions)

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.Header().Set("Content-Length", strconv.Itoa(len(finalScript)))
	fmt.Fprint(w, finalScript)
	recordMetrics("file_serve", r.Method, "200")
}

func (a *app) statsReportHandler(w http.ResponseWriter, r *http.Request) {
	count := atomic.LoadUint64(&requestCounter)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%d", count)
	recordMetrics("stats", r.Method, "200")
}

func (a *app) rootPathHandler(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, a.cfg.RedirectURL, http.StatusFound) // 302 redirect
	recordMetrics("root", r.Method, "302")
}

func (a *app) reloadRepoHandler(w http.ResponseWriter, r *http.Request) {
	report, err := reloadRepo(a.cfg)
	if err != nil {
		recordMetrics("reload", r.Method, "500")
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%s\n", report)
	recordMetrics("reload", r.Method, "200")
}

func (a *app) mainRouter(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/stats" {
		a.statsReportHandler(w, r)
		return
	}
	if r.URL.Path == "/metrics" {
		promhttp.Handler().ServeHTTP(w, r)
		return
	}
	atomic.AddUint64(&requestCounter, 1)

	if r.URL.Path == "/reload" {
		a.reloadRepoHandler(w, r)
		return
	}
	if r.URL.Path == "/" {
		a.rootPathHandler(w, r)
		return
	}

	trimmedPath := strings.TrimPrefix(r.URL.Path, "/")
	parts := strings.SplitN(trimmedPath, "/", 2)
	encodedData := parts[0]

	if encodedData == "" {
		a.rootPathHandler(w, r)
		return
	}

	encodedData = resolveThemeSegment(encodedData, r)

	if len(parts) == 1 {
		a.serveDecodedColorsOnlyHandler(w, r, encodedData)
	} else if len(parts) == 2 {
		filePath := parts[1]
		if filePath == "" {
			recordMetrics("file_serve", r.Method, "400")
			http.Error(w, "File path cannot be empty if a second slash is provided.", http.StatusBadRequest)
			return
		}
		a.serveFileHandler(w, r, encodedData, filePath)
	}
}

// handler wires the router up for both listeners.
func (a *app) handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/", a.mainRouter)
	return mux
}
