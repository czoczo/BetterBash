#!/bin/sh
#
# Shell lint of the BetterBash scripts.
#
#   ./tests/test-shellcheck.sh
#
# The installer and the theme library are held to POSIX shell: they run before
# it is known what shell the user has, so a bashism in them breaks people. The
# prompt itself is bash, and is linted as bash without style noise.
#
# prompt/git-prompt.sh is excluded on purpose: it is the upstream git prompt
# helper, not ours to tidy. The last check feeds shellcheck a deliberate bashism
# and requires it to be reported, so that a passing run keeps meaning something.
#
# Needs shellcheck: on Debian/Ubuntu, apt-get install shellcheck.

set -u

# The script lists its files relative to the repository, so it can be started
# from anywhere.
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$REPO_ROOT" || exit 1

if ! command -v shellcheck >/dev/null 2>&1; then
  printf 'shellcheck not installed; on Debian/Ubuntu: apt-get install shellcheck\n' >&2
  exit 127
fi

# The files that have to be usable by any POSIX shell.
POSIX_SCRIPTS='
installbb.sh
getbb.sh
removebb.sh
test-install.sh
tests/stage-downloads.sh
tests/test-legacy-pipe.sh
tests/test-shellcheck.sh
tests/test-theme.sh
'

# Bash only, and without style level findings.
BASH_SCRIPTS='
prompt/bb.sh
dev.sh
'

FAILED=0

printf '==> POSIX shell (sh)\n'
# shellcheck disable=SC2086
shellcheck -s sh -S warning $POSIX_SCRIPTS || FAILED=1

printf '==> bash\n'
# shellcheck disable=SC2086
shellcheck -s bash -S warning $BASH_SCRIPTS || FAILED=1

# A gate that cannot fail is not a gate, so one deliberate bashism has to be
# reported in a file of its own.
printf '==> and it does notice a bashism\n'
WORK_BAD=$(mktemp -d) || exit 1
BAD_LINT=$WORK_BAD/shellcheck-bad.sh
cat >"$BAD_LINT" <<-'BAD'
	#!/bin/sh
	array=( a b )
	echo "${array[0]}"
BAD
if shellcheck -s sh -S warning "$BAD_LINT" 2>/dev/null | grep -q SC3054; then
  printf '  \033[32mok\033[0m   a bashism in a POSIX script is reported\n'
else
  printf '  \033[31mFAIL\033[0m a bashism in a POSIX script is reported\n'
  FAILED=1
fi
rm -rf "$WORK_BAD"

if [ "$FAILED" = "0" ]; then
  printf '\nshell scripts are clean\n'
else
  printf '\nshellcheck reported problems\n' >&2
fi
exit "$FAILED"
