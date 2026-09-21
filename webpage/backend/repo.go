package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"strings"
	"sync"

	"github.com/go-git/go-git/v5"
	"github.com/go-git/go-git/v5/config"
	"github.com/go-git/go-git/v5/plumbing"
)

var repoMutex sync.Mutex

// cloneRepository clones the configured remote into path.
func cloneRepository(url, path, branch string) error {
	log.Printf("Cloning repository from %s to %s...", url, path)

	options := &git.CloneOptions{
		URL:      url,
		Progress: io.Discard, // Suppress progress output
	}
	if branch != "" {
		options.ReferenceName = plumbing.NewBranchReferenceName(branch)
		options.SingleBranch = true
	}

	if _, err := git.PlainClone(path, false, options); err != nil {
		// A renamed branch is only visible as a failed clone, so name the branch
		// and the knobs that can fix it.
		return fmt.Errorf("failed to clone branch %q of %s into %s (see BB_REPO_BRANCH and BB_REPO_URL): %w", branch, url, path, err)
	}

	log.Printf("Repository cloned successfully to %s", path)
	return nil
}

// pullRepository resets path onto the configured remote branch, the equivalent
// of `git fetch origin && git reset --hard origin/<branch>`.
func pullRepository(path, branch string) error {
	log.Printf("Opening repository at %s", path)

	repo, err := git.PlainOpen(path)
	if err != nil {
		return fmt.Errorf("failed to open repository: %w", err)
	}

	worktree, err := repo.Worktree()
	if err != nil {
		return fmt.Errorf("failed to get worktree: %w", err)
	}

	log.Printf("Fetching latest changes...")
	fetchOptions := &git.FetchOptions{RemoteName: "origin", Progress: io.Discard}
	if branch != "" {
		// Ask for the configured branch explicitly, so changing BB_REPO_BRANCH on
		// an existing single branch checkout still works.
		fetchOptions.RefSpecs = []config.RefSpec{config.RefSpec(fmt.Sprintf("+refs/heads/%s:refs/remotes/origin/%s", branch, branch))}
	}
	if err := repo.Fetch(fetchOptions); err != nil && err != git.NoErrAlreadyUpToDate {
		return fmt.Errorf("failed to fetch: %w", err)
	}

	remoteRefName := plumbing.NewRemoteReferenceName("origin", branch)
	ref, err := repo.Reference(remoteRefName, true)
	if err != nil {
		return fmt.Errorf("failed to get remote reference %s: %w", remoteRefName, err)
	}

	log.Printf("Resetting to %s...", remoteRefName)
	if err := worktree.Reset(&git.ResetOptions{Commit: ref.Hash(), Mode: git.HardReset}); err != nil {
		return fmt.Errorf("failed to reset: %w", err)
	}

	log.Printf("Repository updated successfully")
	return nil
}

// getLatestCommitInfo returns information about the latest commit.
func getLatestCommitInfo(path string) (string, error) {
	repo, err := git.PlainOpen(path)
	if err != nil {
		return "", fmt.Errorf("failed to open repository: %w", err)
	}

	ref, err := repo.Head()
	if err != nil {
		return "", fmt.Errorf("failed to get HEAD: %w", err)
	}

	commit, err := repo.CommitObject(ref.Hash())
	if err != nil {
		return "", fmt.Errorf("failed to get commit: %w", err)
	}

	return fmt.Sprintf("Latest commit: %s\nAuthor: %s\nDate: %s\nMessage: %s",
		commit.Hash.String()[:8],
		commit.Author.Name,
		commit.Author.When.Format("2006-01-02 15:04:05"),
		strings.TrimSpace(commit.Message)), nil
}

// ensureRepo makes sure the configured repository path holds files that can be
// served. A local working checkout is only verified, never cloned into.
func ensureRepo(cfg *Config) error {
	if _, err := os.Stat(cfg.Repo.Path); err == nil {
		log.Printf("Local repository found at %s. Skipping clone.", cfg.Repo.Path)
		return nil
	} else if !os.IsNotExist(err) {
		return fmt.Errorf("failed to inspect repository path %s: %w", cfg.Repo.Path, err)
	}

	if cfg.Repo.LocalCheckout {
		return fmt.Errorf("no working copy at %s; run the backend from %s or point BB_REPO_PATH at a checkout of %s",
			cfg.Repo.Path, defaultDevRepoPath, defaultProdRepoURL)
	}

	log.Printf("Local repository not found at %s. Cloning %s...", cfg.Repo.Path, cfg.Repo.URL)
	if err := cloneRepository(cfg.Repo.URL, cfg.Repo.Path, cfg.Repo.Branch); err != nil {
		return fmt.Errorf("failed to clone repository: %w", err)
	}
	log.Printf("Repository cloned successfully into %s.", cfg.Repo.Path)
	return nil
}

// setupRepo prepares the repository on startup.
func setupRepo(cfg *Config) error {
	repoMutex.Lock()
	defer repoMutex.Unlock()
	return ensureRepo(cfg)
}

// reloadRepo refreshes the served files and returns a human readable report.
func reloadRepo(cfg *Config) (string, error) {
	repoMutex.Lock()
	defer repoMutex.Unlock()

	if _, err := os.Stat(cfg.Repo.Path); os.IsNotExist(err) {
		log.Printf("Local repository at %s does not exist. Cloning first.", cfg.Repo.Path)
		if cfg.Repo.LocalCheckout {
			return "", fmt.Errorf("working copy missing at %s; start the backend inside the repository or set BB_REPO_PATH", cfg.Repo.Path)
		}
		if err := cloneRepository(cfg.Repo.URL, cfg.Repo.Path, cfg.Repo.Branch); err != nil {
			return "", fmt.Errorf("failed to clone repository during reload: %w", err)
		}
		return "Repository was missing, cloned successfully.", nil
	}

	if cfg.Repo.LocalCheckout {
		info := fmt.Sprintf("Serving working copy at %s; pulling is disabled in development. Files are read from disk on every request.", cfg.Repo.Path)
		log.Println(info)
		return info, nil
	}

	log.Printf("Attempting to pull latest changes for repository at %s", cfg.Repo.Path)
	if err := pullRepository(cfg.Repo.Path, cfg.Repo.Branch); err != nil {
		errMsg := fmt.Sprintf("Failed to pull latest changes: %v", err)
		log.Println(errMsg)
		return "", err
	}

	commitInfo, err := getLatestCommitInfo(cfg.Repo.Path)
	if err != nil {
		log.Printf("Warning: Could not get commit info: %v", err)
		commitInfo = "Commit info unavailable"
	}

	log.Println("Repository reloaded successfully.")
	return fmt.Sprintf("Repository reloaded successfully.\n%s\n", commitInfo), nil
}
