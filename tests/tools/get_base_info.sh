# Find the target directory or file
ARTIFACT_NAME=$(ls | grep "profile_optiprofiler" | head -n 1)
# Extract the base information and remove any carriage returns or newlines
BASE_INFO=$(echo "$ARTIFACT_NAME" | sed -n 's/.*optiprofiler_\(.*_\(small\|big\|large\)\).*/\1/p' | tr -d '\r\n')