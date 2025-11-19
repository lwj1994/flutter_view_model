#!/bin/sh
# This script runs dart fix and dart format to clean up the codebase.

# Exit immediately if a command exits with a non-zero status.
set -e

echo "Running 'dart fix --apply'..."
dart fix --apply

echo "Running 'dart format .'..."
dart format .

echo "Fix and format complete!"
