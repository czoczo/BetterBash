package main

import (
	"bytes"
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"sync/atomic"
)

const (
	gitRepoURL    = "https://git.cz0.cz/czoczo/BetterBash"
	localRepoPath = "BetterBashRepo" // Cloned into a subdirectory
	bbShellPath   = "prompt/bb.sh"
)

var (
	// requestCounter stores the number of HTTP requests (excluding /stats and /reload).
	requestCounter uint64
	// repoMutex protects git operations like clone/pull
	repoMutex sync.Mutex
)

// colorComponentKeys defines the names for the color components in their encoding order.
var colorComponentKeys = []string{
	"PRIMARY_COLOR",
	"SECONDARY_COLOR",
	"ROOT_COLOR",
	"TIME_COLOR",
	"ERR_COLOR",
	"SEPARATOR_COLOR",
	"BORDCOL",
	"PATH_COLOR",
	// The 9th component (C9, potentially "Reset") is decoded but not listed for output.
}

// decodeColorLogic processes the encoded data string and returns color information.
// It returns a map of color keys to bash color values, a formatted string list of these, and an error.
func decodeColorLogic(encodedData string) (map[string]string, string, error) {
	standardBase64 := strings.ReplaceAll(encodedData, "-", "+")
	standardBase64 = strings.ReplaceAll(standardBase64, "_", "/")

	decodedBytes, err := base64.RawStdEncoding.DecodeString(standardBase64)
	if err != nil {
		return nil, "", fmt.Errorf("Base64 decoding failed: %v. Input: '%s'", err, encodedData)
	}

	if len(decodedBytes) != 6 {
		return nil, "", fmt.Errorf("Decoded data must be 6 bytes long, got %d bytes from input '%s'", len(decodedBytes), encodedData)
	}

	fiveBitValues := make([]byte, 9)
	b := decodedBytes
	fiveBitValues[0] = b[0] >> 3
	fiveBitValues[1] = ((b[0] & 0x07) << 2) | (b[1] >> 6)
	fiveBitValues[2] = (b[1] & 0x3E) >> 1
	fiveBitValues[3] = ((b[1] & 0x01) << 4) | (b[2] >> 4)
	fiveBitValues[4] = ((b[2] & 0x0F) << 1) | (b[3] >> 7)
	fiveBitValues[5] = (b[3] & 0x7C) >> 2
	fiveBitValues[6] = ((b[3] & 0x03) << 3) | (b[4] >> 5)
	fiveBitValues[7] = b[4] & 0x1F
	fiveBitValues[8] = b[5] >> 3 // C9, not used in direct output string but decoded

	colorsMap := make(map[string]string)
	var resultList strings.Builder

	for i := 0; i < 8; i++ { // Only first 8 components for output
		val5bit := fiveBitValues[i]
		baseColor07 := (val5bit >> 2) & 0x07
		lightBit := (val5bit >> 1) & 0x01
		boldBit := val5bit & 0x01

		baseAnsiCode := baseColor07 + 30
		actualAnsiCode := baseAnsiCode
		if lightBit == 1 {
			actualAnsiCode += 60
		}
		styleAttr := 0
		if boldBit == 1 {
			styleAttr = 1
		}

		bashColor := fmt.Sprintf(`\[\033[%d;%dm\]`, styleAttr, actualAnsiCode)
		colorsMap[colorComponentKeys[i]] = bashColor
		resultList.WriteString(fmt.Sprintf("%s='%s'\n", colorComponentKeys[i], bashColor))
	}

	return colorsMap, strings.TrimSpace(resultList.String()), nil
}

// serveDecodedColorsOnlyHandler serves only the decoded color definitions.
func serveDecodedColorsOnlyHandler(w http.ResponseWriter, r *http.Request, encodedData string) {
	_, formattedOutput, err := decodeColorLogic(encodedData)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprint(w, formattedOutput)
}

// serveFileWithColorsHandler serves files from the repo, potentially modifying bb.sh.
func serveFileWithColorsHandler(w http.ResponseWriter, r *http.Request, encodedData string, requestedFilePath string) {
	colorsMap, _, err := decodeColorLogic(encodedData)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode colors: %v", err), http.StatusBadRequest)
		return
	}

	// Sanitize file path
	cleanFilePath := filepath.Clean(requestedFilePath)
	if strings.HasPrefix(cleanFilePath, "..") || strings.HasPrefix(cleanFilePath, "/") {
		http.Error(w, "Invalid file path.", http.StatusBadRequest)
		return
	}

	fullPath := filepath.Join(localRepoPath, cleanFilePath)

	// Security check: ensure the path is still within the localRepoPath
	absRepoPath, _ := filepath.Abs(localRepoPath)
	absFilePath, _ := filepath.Abs(fullPath)
	if !strings.HasPrefix(absFilePath, absRepoPath) {
		http.Error(w, "Access to file path denied.", http.StatusForbidden)
		return
	}

	fileInfo, err := os.Stat(fullPath)
	if os.IsNotExist(err) {
		http.Error(w, fmt.Sprintf("File not found: %s", requestedFilePath), http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, fmt.Sprintf("Error accessing file: %v", err), http.StatusInternalServerError)
		return
	}
	if fileInfo.IsDir() {
		http.Error(w, fmt.Sprintf("Requested path is a directory: %s", requestedFilePath), http.StatusBadRequest)
		return
	}


	if cleanFilePath == bbShellPath {
		// Special handling for prompt/bb.sh
		content, err := os.ReadFile(fullPath)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error reading %s: %v", bbShellPath, err), http.StatusInternalServerError)
			return
		}

		modifiedScript := string(content)
		for key, colorValue := range colorsMap {
			// Regex to find lines like `KEY='...'`, `export KEY="..."`, or `KEY=value`
			// It captures `export ` (if present) and the key name.
			// It replaces the whole line.
			// We need to be careful with shell syntax. For simplicity, we assume KEY='...'
			// For robust parsing, a proper shell parser would be needed.
			// This regex looks for `KEY=`, potentially with `export` prefix, and replaces value.
			// It assumes the value is single-quoted or simply the rest of the line.
			// Example: PRIMARY_COLOR='...' or export PRIMARY_COLOR='...'
			regex := regexp.MustCompile(fmt.Sprintf(`^(export\s+)?%s\s*=\s*('.*?'|".*?"|[^#\s]*)`, regexp.QuoteMeta(key)))
			replacement := fmt.Sprintf("${1}%s='%s'", key, colorValue)
			modifiedScript = regex.ReplaceAllString(modifiedScript, replacement)
		}

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		fmt.Fprint(w, modifiedScript)
	} else {
		// Serve other files as is
		http.ServeFile(w, r, fullPath)
	}
}

// statsReportHandler serves the HTTP request counter.
func statsReportHandler(w http.ResponseWriter, r *http.Request) {
	count := atomic.LoadUint64(&requestCounter)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%d", count)
}

// rootPathHandler handles requests to the bare "/" path.
func rootPathHandler(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Please provide an encoded string in the URL path (e.g., /YourEncodedString) or a file path (e.g. /YourEncodedString/path/to/file.sh)", http.StatusBadRequest)
}

// runGitCommand executes a git command and logs its output.
func runGitCommand(dir string, args ...string) error {
	cmd := exec.Command("git", args...)
	if dir != "" {
		cmd.Dir = dir
	}
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr

	log.Printf("Running git command: git %s in dir '%s'", strings.Join(args, " "), dir)
	err := cmd.Run()
	if out.Len() > 0 {
		log.Printf("git stdout: %s", out.String())
	}
	if stderr.Len() > 0 {
		log.Printf("git stderr: %s", stderr.String())
	}
	if err != nil {
		return fmt.Errorf("git %s failed: %v\nstderr: %s", strings.Join(args, " "), err, stderr.String())
	}
	return nil
}

// setupRepo clones the repository if it doesn't exist locally.
func setupRepo() error {
	repoMutex.Lock()
	defer repoMutex.Unlock()

	if _, err := os.Stat(localRepoPath); os.IsNotExist(err) {
		log.Printf("Local repository not found at %s. Cloning %s...", localRepoPath, gitRepoURL)
		if err := runGitCommand("", "clone", gitRepoURL, localRepoPath); err != nil {
			return fmt.Errorf("failed to clone repository: %w", err)
		}
		log.Printf("Repository cloned successfully into %s.", localRepoPath)
	} else {
		log.Printf("Local repository found at %s. Skipping clone.", localRepoPath)
		// Optionally, pull latest on startup too
		// log.Printf("Pulling latest changes for %s...", localRepoPath)
		// if err := runGitCommand(localRepoPath, "pull", "origin", "master"); err != nil {
		//  return fmt.Errorf("failed to pull repository on startup: %w", err)
		// }
		// log.Printf("Repository updated successfully.")
	}
	return nil
}

// reloadRepoHandler handles the /reload endpoint to pull the latest from git.
func reloadRepoHandler(w http.ResponseWriter, r *http.Request) {
	repoMutex.Lock()
	defer repoMutex.Unlock()

	log.Printf("Attempting to pull latest changes for repository at %s", localRepoPath)
	// Ensure the repo exists before trying to pull
	if _, err := os.Stat(localRepoPath); os.IsNotExist(err) {
		log.Printf("Local repository at %s does not exist. Cloning first.", localRepoPath)
		if err := runGitCommand("", "clone", gitRepoURL, localRepoPath); err != nil {
			http.Error(w, fmt.Sprintf("Failed to clone repository during reload: %v", err), http.StatusInternalServerError)
			return
		}
		log.Printf("Repository cloned successfully during reload.")
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		fmt.Fprintln(w, "Repository was missing, cloned successfully.")
		return
	}

	// Attempt to reset any local changes and then pull
	// This is a forceful way to ensure it matches origin/master
	// Be cautious with `git reset --hard` if local changes could be important,
	// but for a cache/mirror this is often desired.
	err := runGitCommand(localRepoPath, "fetch", "origin")
	if err == nil {
		err = runGitCommand(localRepoPath, "reset", "--hard", "origin/master")
	}
	// Fallback to simple pull if reset fails or as primary strategy
	if err != nil {
		log.Printf("Hard reset failed (or fetch failed): %v. Attempting simple pull.", err)
		err = runGitCommand(localRepoPath, "pull", "origin", "master")
	}
	
	if err != nil {
		errMsg := fmt.Sprintf("Failed to pull latest changes: %v", err)
		log.Println(errMsg)
		http.Error(w, errMsg, http.StatusInternalServerError)
		return
	}

	log.Println("Repository reloaded successfully.")
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintln(w, "Repository reloaded successfully.")
}

// mainRouter is the primary HTTP handler.
func mainRouter(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/stats" {
		statsReportHandler(w, r)
		return
	}

	// Increment request counter for non-stats paths.
	// Reload is also a functional path so we count it.
	atomic.AddUint64(&requestCounter, 1)

	if r.URL.Path == "/reload" {
		reloadRepoHandler(w, r)
		return
	}

	if r.URL.Path == "/" {
		rootPathHandler(w, r)
		return
	}

	// Path structure: /<encoded_data>[/<file_path>]
	trimmedPath := strings.TrimPrefix(r.URL.Path, "/")
	parts := strings.SplitN(trimmedPath, "/", 2)

	encodedData := parts[0]
	if encodedData == "" { // Path was just "/" or "//..."
		rootPathHandler(w, r) // Or a more specific error
		return
	}

	if len(parts) == 1 {
		// Only /<encoded_data>
		serveDecodedColorsOnlyHandler(w, r, encodedData)
	} else if len(parts) == 2 {
		// /<encoded_data>/<file_path>
		filePath := parts[1]
		if filePath == "" { // e.g. /encodedData/
			http.Error(w, "File path cannot be empty if a second slash is provided.", http.StatusBadRequest)
			return
		}
		serveFileWithColorsHandler(w, r, encodedData, filePath)
	}
	// SplitN with 2 parts will always result in len 1 or 2 if input is not empty.
	// If trimmedPath was empty, parts would be {""}, len 1. This is caught by encodedData==""
}

func main() {
	// Clone the repository at startup if it doesn't exist
	if err := setupRepo(); err != nil {
		log.Fatalf("❌ Failed to setup repository: %s\n", err)
		// Depending on strictness, you might want to os.Exit(1) or try to run without the repo functionality
	}

	http.HandleFunc("/", mainRouter)

	port := "8080"
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	log.Printf("🎨 Color Theme Backend & File Server starting on port %s (e.g., http://localhost:%s)\n", port, port)
	log.Printf("Git Repo URL: %s", gitRepoURL)
	log.Printf("Local Repo Path: ./%s", localRepoPath)
	log.Printf("Special file for color replacement: %s", bbShellPath)
	log.Printf("Endpoints:")
	log.Printf("  GET /<encoded_color_data>         - Show color definitions")
	log.Printf("  GET /<encoded_color_data>/<path> - Serve file from repo (e.g., /VcrS_H8A/removebb.sh)")
	log.Printf("                                    Special: /<encoded_color_data>/%s for dynamic colors", bbShellPath)
	log.Printf("  GET /reload                       - Pull latest from git master branch")
	log.Printf("  GET /stats                        - Show request count")
	log.Printf("  GET /                             - Show usage instructions")


	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatalf("❌ Failed to start server: %s\n", err)
	}
}
