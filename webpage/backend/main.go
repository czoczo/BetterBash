package main

import (
//	"bufio" // Keep for other potential uses, though not strictly needed for the new bb.sh logic if using SplitN
	"bytes"
	"encoding/base64"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
//	"regexp" // Keep for other potential uses, though not for bb.sh color insertion
	"strings"
	"sync"
	"sync/atomic"
)

const (
	gitRepoURL    = "https://git.cz0.cz/czoczo/BetterBash"
	localRepoPath = "BetterBashRepo" // Cloned into a subdirectory
	bbShellPath   = "prompt/bb.sh"
	getBbPath   = "getbb.sh"
)

var (
	requestCounter uint64
	repoMutex      sync.Mutex
)

var colorComponentKeys = []string{
	"PRIMARY_COLOR", "SECONDARY_COLOR", "ROOT_COLOR", "TIME_COLOR",
	"ERR_COLOR", "SEPARATOR_COLOR", "BORDCOL", "PATH_COLOR",
}

func decodeColorLogic(encodedData string) (map[string]string, string, bool, error) {
	standardBase64 := strings.ReplaceAll(encodedData, "-", "+")
	standardBase64 = strings.ReplaceAll(standardBase64, "_", "/")

	decodedBytes, err := base64.RawStdEncoding.DecodeString(standardBase64)
	if err != nil {
		return nil, "", false, fmt.Errorf("Base64 decoding failed: %v. Input: '%s'", err, encodedData)
	}

	if len(decodedBytes) != 6 {
		return nil, "", false, fmt.Errorf("Decoded data must be 6 bytes long, got %d bytes from input '%s'", len(decodedBytes), encodedData)
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
	fiveBitValues[8] = b[5] >> 3

	// Extract avatar bit from the first bit of the 6th byte
	avatarEnabled := (b[5] & 0x80) != 0

	colorsMap := make(map[string]string)
	var resultList strings.Builder

	for i := 0; i < 8; i++ {
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
		// Ensure each definition is on a new line, directly usable in shell script
		resultList.WriteString(fmt.Sprintf("%s='%s'\n", colorComponentKeys[i], bashColor))
	}

	// Add the AVATAR variable
	avatarValue := "false"
	if avatarEnabled {
		avatarValue = "true"
	}
	resultList.WriteString(fmt.Sprintf("AVATAR='%s'\n", avatarValue))

	// Remove the last newline character from the block of definitions if present for cleaner insertion
	return colorsMap, strings.TrimSuffix(resultList.String(), "\n"), avatarEnabled, nil
}

func serveDecodedColorsOnlyHandler(w http.ResponseWriter, r *http.Request, encodedData string) {
	_, formattedOutput, _, err := decodeColorLogic(encodedData)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	// The formattedOutput from decodeColorLogic is already KEY='VAL'\nKEY2='VAL2'
	// So it prints multiple lines as intended.
	fmt.Fprintln(w, formattedOutput)
}

// serveFileWithColorsHandler serves files from the repo, potentially modifying bb.sh.
func serveFileWithColorsHandler(w http.ResponseWriter, r *http.Request, encodedData string, requestedFilePath string) {
	// Note: The 'colorsMap' is not strictly needed for the new bb.sh logic,
	// as 'formattedColorDefinitions' is used directly. But decodeColorLogic provides it.
	_, formattedColorDefinitions, _, err := decodeColorLogic(encodedData)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to decode colors: %v", err), http.StatusBadRequest)
		return
	}

	cleanFilePath := filepath.Clean(requestedFilePath)
	if strings.HasPrefix(cleanFilePath, "..") || strings.HasPrefix(cleanFilePath, "/") {
		http.Error(w, "Invalid file path.", http.StatusBadRequest)
		return
	}

	fullPath := filepath.Join(localRepoPath, cleanFilePath)
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

	if cleanFilePath == getBbPath {
		originalContentBytes, err := os.ReadFile(fullPath)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error reading %s: %v", getBbPath, err), http.StatusInternalServerError)
			return
		}
		originalContent := string(originalContentBytes)
		originalContent = strings.Replace(originalContent, "git.cz0.cz", r.Host, -1)
		originalContent = strings.Replace(originalContent, "/czoczo/BetterBash/raw/branch/master", fmt.Sprintf("/%s", encodedData), -1)

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		fmt.Fprint(w, originalContent)
	} else if cleanFilePath == bbShellPath {
		originalContentBytes, err := os.ReadFile(fullPath)
		if err != nil {
			http.Error(w, fmt.Sprintf("Error reading %s: %v", bbShellPath, err), http.StatusInternalServerError)
			return
		}
		originalContent := string(originalContentBytes)

		var finalScript strings.Builder

		// Split the original content to find the shebang and the rest of the script
		lines := strings.SplitN(originalContent, "\n", 2)
		firstLineOriginal := ""
		restOfScript := ""

		if len(lines) > 0 {
			firstLineOriginal = lines[0]
		}

		// Correctly assign restOfScript
		if len(lines) > 1 {
			restOfScript = lines[1]
		} else if len(lines) == 1 { // Script might be a single line or empty
		    if originalContent == firstLineOriginal { // single line script
		        restOfScript = ""
		    } else { // empty script, lines[0] would be ""
		        restOfScript = ""
		    }
		}


		if strings.HasPrefix(firstLineOriginal, "#!") {
			finalScript.WriteString(firstLineOriginal) // Write shebang
			finalScript.WriteString("\n")              // Newline after shebang
			finalScript.WriteString(formattedColorDefinitions) // This is KEY='VAL'\nKEY2='VAL2'\nAVATAR='true/false'
			finalScript.WriteString("\n")              // Ensure a newline after the injected block
			if restOfScript != "" {
				finalScript.WriteString(restOfScript)
			}
		} else {
			// No shebang, or script didn't start with it.
			// Per revised requirement, we should still try to inject.
			// Prepend colors to the original content.
			finalScript.WriteString(formattedColorDefinitions)
			finalScript.WriteString("\n")
			finalScript.WriteString(originalContent)
		}

		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		fmt.Fprint(w, finalScript.String())
	} else {
		http.ServeFile(w, r, fullPath)
	}
}

func statsReportHandler(w http.ResponseWriter, r *http.Request) {
	count := atomic.LoadUint64(&requestCounter)
	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	fmt.Fprintf(w, "%d", count)
}

func rootPathHandler(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "Please provide an encoded string in the URL path (e.g., /YourEncodedString) or a file path (e.g. /YourEncodedString/path/to/file.sh)", http.StatusBadRequest)
}

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
	}
	return nil
}

func reloadRepoHandler(w http.ResponseWriter, r *http.Request) {
	repoMutex.Lock()
	defer repoMutex.Unlock()

	log.Printf("Attempting to pull latest changes for repository at %s", localRepoPath)
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

	err := runGitCommand(localRepoPath, "fetch", "origin")
	if err == nil {
		err = runGitCommand(localRepoPath, "reset", "--hard", "origin/master")
	}
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

func mainRouter(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path == "/stats" {
		statsReportHandler(w, r)
		return
	}
	atomic.AddUint64(&requestCounter, 1)

	if r.URL.Path == "/reload" {
		reloadRepoHandler(w, r)
		return
	}
	if r.URL.Path == "/" {
		rootPathHandler(w, r)
		return
	}

	trimmedPath := strings.TrimPrefix(r.URL.Path, "/")
	parts := strings.SplitN(trimmedPath, "/", 2)
	encodedData := parts[0]

	if encodedData == "" {
		rootPathHandler(w, r)
		return
	}

	if len(parts) == 1 {
		serveDecodedColorsOnlyHandler(w, r, encodedData)
	} else if len(parts) == 2 {
		filePath := parts[1]
		if filePath == "" {
			http.Error(w, "File path cannot be empty if a second slash is provided.", http.StatusBadRequest)
			return
		}
		serveFileWithColorsHandler(w, r, encodedData, filePath)
	}
}

func main() {
	if err := setupRepo(); err != nil {
		log.Fatalf("❌ Failed to setup repository: %s\n", err)
	}

	http.HandleFunc("/", mainRouter)
	port := "8080"
	if p := os.Getenv("PORT"); p != "" {
		port = p
	}

	log.Printf("🎨 Color Theme Backend & File Server starting on port %s (e.g., http://localhost:%s)\n", port, port)
	log.Printf("Git Repo URL: %s", gitRepoURL)
	log.Printf("Local Repo Path: ./%s", localRepoPath)
	log.Printf("Special file for color injection: %s", bbShellPath)
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
