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
COMMAND=
VALUES=

# First pass: capture -n and -f flags
while (( "$#" )); do
  case "$1" in
    -n) NAMESPACE="$2"; shift ;;
    -f) VALUES="$2"; shift ;;
  esac
  shift
done

# Reset positional parameters
set -- $COMMAND

# Second pass: build the command
while (( "$#" )); do
  case "$1" in
    --quiet|-q) QUIET=1  ;;
    -n|-f) shift ;; # Skip -n and -f flags
    *) COMMAND="$COMMAND $1" ;; # Concatenate other arguments into the command
  esac
  shift
done

# Check if Helm command and values file were provided
if [ -z "$COMMAND" ] || [ -z "$VALUES" ]
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
cp $VALUES $temp_values

header "Fetching and replacing secrets"

# Find all placeholders enclosed within {}
placeholders=$(grep -oP '{\K[^}]+' $VALUES)

for placeholder in $placeholders
do
  # Split placeholder into secret name and key
  IFS='.' read -r secret_name secret_key <<< "$placeholder"
  
  # Fetch secret
  secret=$(kubectl -n $NAMESPACE get secret $secret_name -o jsonpath="{.data.$secret_key}" | base64 --decode)

  # Replace placeholder in temporary file
  sed -i "s/{$placeholder}/$secret/g" $temp_values
done

header "Running Helm command"

# Run the Helm command with the temporary values file
eval "helm $COMMAND -f $temp_values"

header "Cleaning up"

# Remove the temporary file
rm $temp_values

header "Done"
