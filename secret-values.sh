#!/bin/bash

set -euo pipefail

# -----------------------------------------------------------------------------
# usage

usage() {
cat << EOF
Replace placeholders in values file with secrets and run the Helm command.

Usage:
  helm secret-values <helm command> -f <values.yaml> [-n namespace]

Options:
  -q, --quiet          don't print headers

EOF

  exit
}

# -----------------------------------------------------------------------------
# rule
# Print a horizontal line the width of the terminal.

rule() {
  local cols="${COLUMNS:-$(tput cols)}"
  local char=$'\u2500'
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}

# -----------------------------------------------------------------------------
# header
# Print step header text in a consistent way

header() {
  if [[ "${QUIET}" ]]; then
    return
  fi

  local msg="$*"
  printf "\n%s[%s]\n\n" "$(rule)" "${msg}"
}

# -----------------------------------------------------------------------------
# main

QUIET=
NAMESPACE=default

while [[ $# -ne 0 ]]; do
  case "$1" in
    --quiet|-q)        QUIET=1  ;;
    -n)                NAMESPACE="$2"; shift ;;
    -*)                usage "Unrecognized command line argument $1" ;;
    *)                 break;
  esac
  shift
done

# Check if Helm command and values file were provided
if [ -z "$1" ] || [ "$2" != "-f" ] || [ -z "$3" ]
then
  header "Error"
  echo "Please call the plugin with 'helm secret-values <helm command> -f <values.yaml>'"
  exit 1
fi

header "Creating temporary values file"

# Create temporary file
temp_values=$(mktemp)
chmod 600 $temp_values

# Make a copy of the values file
cp $3 $temp_values

header "Fetching and replacing secrets"

# Find all placeholders enclosed within {}
placeholders=$(grep -oP '{\K[^}]+' $3)

for placeholder in $placeholders
do
  # Fetch secret
  secret=$(kubectl -n $NAMESPACE get secret my-secret -o jsonpath="{.data.$placeholder}" | base64 --decode)

  # Replace placeholder in temporary file
  sed -i "s/{$placeholder}/$secret/g" $temp_values
done

header "Running Helm command"

# Remove the first three arguments (Helm command, -f, and values.yaml) from the arguments list
shift 3

# Run the Helm command with the temporary values file
"$1" -f "$temp_values" "$@"

header "Cleaning up"

# Remove the temporary file
rm $temp_values

header "Done"
