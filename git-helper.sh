#! /bin/bash
#
# git-helper.sh - a script to help with common git tasks and best practices.
#
# author: Ravza Unal <ravza.unal@student.hogent.be>

#------------------------------------------------------------------------------
# Shell settings
#------------------------------------------------------------------------------
set -euo pipefail
#------------------------------------------------------------------------------
# Variables
#------------------------------------------------------------------------------
GIT_USER_NAME=$(git config --get user.name || echo "User Name Not Set")
GIT_USER_EMAIL=$(git config --get user.email || echo "User Email Not Set")
#------------------------------------------------------------------------------
# Main function
#------------------------------------------------------------------------------

# Usage: main "${@}"
#  Check command line arguments (using a case statement) and call the
#  appropriate function that implements the functionality.
main() {
  if [ "${#}" -eq 0 ]; then
    usage
  fi

  case "${1:-}" in
    "check")
      check_basic_settings
      ;;
    "check_repo")
      check_repo "${2:-.}"
      ;;
    "log" | "show_history")
      show_history "${2:-.}"
      ;;
    "stats")
      stats "${2:-.}"
      ;;
    "undo")
      undo_last_commit
      ;;
    "sync")
      sync
      ;;
    "help" | "-h" | "--help")
      usage
      ;;
    *)
      usage
      ;;
  esac
}

# Usage: show_history [DIR]
#  Show git log in the specified DIR or in the current directory if none was specified.
show_history() {
  local dir="${1:-.}"  # Als er geen directory is opgegeven, gebruik dan de huidige directory

  # Controleer of de opgegeven directory een geldige git-repository is
  if ! is_git_repo "$dir"; then
    echo "$dir is not a valid Git repository." >&2
    exit 1
  fi

  # Verkorte git-log weergeven
  git -C "$dir" log --pretty=format:"%s | %an | %ad" --date=short
}

#------------------------------------------------------------------------------
# Helper functions
#------------------------------------------------------------------------------
# If you notice that you are writing the same code in multiple places, don't
# hesitate to add functions to make your code more DRY!

# Usage: is_git_repo DIR
#  Predicate that checks if the specified DIR contains a Git repository.
#  This function does not produce output, but only returns the appropriate
#  exit code.
is_git_repo() {
   local dir="$1"
  if [ ! -d "$dir/.git" ]; then
    echo "$dir is not a Git repository!" >&2
    return 1
  fi
}

# Usage: check_basic_settings
#  Check if the basic git settings are configured
check_basic_settings() {
  local unset_settings=0

  # Gebruik vooraf gedefinieerde variabelen
  if [ "$GIT_USER_NAME" = "User Name Not Set" ]; then
    echo "Warning: 'user.name' is not set!" >&2
    unset_settings=1
  fi

  if [ "$GIT_USER_EMAIL" = "User Email Not Set" ]; then
    echo "Warning: 'user.email' is not set!" >&2
    unset_settings=1
  fi

  # Controleer push.default
  if ! git config --get push.default &>/dev/null; then
    echo "Warning: 'push.default' is not set!" >&2
    unset_settings=1
  fi

  if [ "$unset_settings" -eq 1 ]; then
    echo "Please configure these settings using the following commands:" >&2
    echo "git config --global user.name 'Your Name'" >&2
    echo "git config --global user.email 'your.email@example.com'" >&2
    echo "git config --global push.default current" >&2
  else
    echo "Git basic settings are properly configured:"
    echo "  user.name: $GIT_USER_NAME"
    echo "  user.email: $GIT_USER_EMAIL"
    echo "  push.default: $(git config --get push.default)"
  fi
}

# Usage: check_repo DIR
#  Perform some checks on the specified DIR that should contain a Git
#  repository.
check_repo() {
  local dir="$1"

  # Controleer of de directory een git-repository is
  if ! is_git_repo "$dir"; then
    echo "$dir is not a valid Git repository." >&2
    exit 1
  fi

  # Controleer op noodzakelijke bestanden in de root
  echo "Checking for necessary files in the repository root..."
  local missing_files=0
  for file in "README.md" ".gitignore" ".gitattributes"; do
    if [ ! -f "$dir/$file" ]; then
      echo "Warning: $file is missing in the repository root." >&2
      missing_files=1
    fi
  done

  if [ "$missing_files" -gt 0 ]; then
    echo "Please add the missing files to the repository root." >&2
  else
    echo "All necessary files are present in the repository root."
  fi

  # Controleer of er een remote is ingesteld
  if ! git -C "$dir" remote -v &>/dev/null; then
    echo "Warning: No remote repository configured." >&2
  else
    echo "Remote repository is configured."
  fi

  # Controleer of alle .sh bestanden uitvoerbaar zijn
  local non_executable_sh_files
  non_executable_sh_files=$(find "$dir" -name "*.sh" ! -executable)
  if [ -n "$non_executable_sh_files" ]; then
    echo "Warning: Some shell scripts are not executable:"
    echo "$non_executable_sh_files"
    read -r -p "Do you want to make them executable and commit the changes? (y/n): " answer
    if [[ "$answer" == "y" ]]; then
      find "$dir" -name "*.sh" -exec chmod +x {} \;
      git -C "$dir" add .
      git -C "$dir" commit -m "Make scripts executable"
      echo "Shell scripts have been made executable and changes have been committed."
    fi
  else
    echo "All shell scripts are executable."
  fi

  # Controleer op ongepaste bestanden (ISO, Word, Excel, ELF-bestanden)
  local inappropriate_files
  inappropriate_files=$(find "$dir" -type f -exec file {} \; | grep -E 'ISO|Word|Excel|ELF')
  if [ -n "$inappropriate_files" ]; then
    echo "Warning: The following inappropriate files were found:"
    echo "$inappropriate_files"
  else
    echo "No inappropriate files found."
  fi
}

# Usage: stats [DIR]
#  Show the number of commits and the number of contributors in the specified
#  DIR or in the current directory if none was specified.
stats() {
  local dir="${1:-.}"  # Als er geen directory is opgegeven, gebruik dan de huidige directory

  # Controleer of de opgegeven directory een geldige git-repository is
  if ! is_git_repo "$dir"; then
    echo "$dir is not a valid Git repository." >&2
    exit 1
  fi

  # Aantal commits in de huidige branch ophalen
  local commit_count
  commit_count=$(git -C "$dir" rev-list --count HEAD)

  # Aantal contributors (unieke auteurs) ophalen
  local contributor_count
  contributor_count=$(git -C "$dir" shortlog -s -n | wc -l)

  # Toon de statistieken
  echo "$commit_count commits by $contributor_count contributors"
}

# Usage: undo_last_commit
#  Undo the last commit but keep local changes in the working directory.
undo_last_commit() {
  # Haal de commit boodschap van de laatste commit op
  local last_commit_message
  last_commit_message=$(git log -1 --pretty=%B)

  # Voer een soft reset uit om de laatste commit te verwijderen, maar de lokale wijzigingen te behouden
  git reset --soft HEAD~1

  # Toon een bericht met de boodschap van de ongedane commit
  echo "Undo of last commit \"$last_commit_message\" successful."
}

# Usage: sync
#  Sync the currently checked out branch in the local repository with the
#  remote repository by performing:
#
#  - git stash if there are local changes
#  - git pull --rebase
#  - git push
#  - git push all labels (tags)
#  - git stash pop if there were local changes
sync() {
  # Controleer of er lokale wijzigingen zijn
if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "Local changes detected."
  echo "Local changes stashed."
  git stash push --include-untracked  # Sla lokale wijzigingen op
fi

# Controleer of er een remote repository is ingesteld
if ! git remote -v &>/dev/null; then
  echo "No remote repository configured. Please add a remote repository."
  return 1  # Stop de uitvoering als er geen remote is ingesteld
fi

# Voer een rebase uit om remote wijzigingen op te halen
if git pull --rebase; then
  echo "Remote changes pulled successfully."
else
  echo "There were conflicts during the pull. Please resolve them."
  git status
  return 1  # Stop de uitvoering als er conflicten zijn
fi

# Push de wijzigingen naar de remote repository
git push
echo "Changes pushed to the remote repository."

# Push alle labels (tags) naar de remote
git push --tags
echo "Tags pushed to the remote repository."

# Als er lokale wijzigingen waren, herstel ze dan
if git stash list | grep -q "stash@{0}"; then
  git stash pop
  echo "Local changes unstashed."
fi
}

# Usage: usage
#   Print usage message
usage() {
  cat <<EOF
Usage: ./git-helper.sh COMMAND [ARGUMENTS]...

Commands:
  check                Check basic git user configuration
  check_repo           Check basic git user configuration and check DIR for deviations of standard git practices
  log                  Display a brief overview of the git log of the current directory
  stats                Display some brief stats about the current repository
  undo                 Undo the last commit from the git working tree while preserving local changes
  sync                 Sync local branch with remote

Examples:
  ./git-helper.sh check
  ./git-helper.sh check /path/to/repo
  ./git-helper.sh log
  ./git-helper.sh stats
  ./git-helper.sh undo
  ./git-helper.sh sync

EOF
  exit 0
}

main "${@}"