#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REQ_FILE="${ROOT_DIR}/docs/screens/video-review.md"
TAG="Requirements: docs/screens/video-review.md"

if [[ ! -f "${REQ_FILE}" ]]; then
  echo "Requirements file not found: ${REQ_FILE}" >&2
  exit 1
fi

matched_files=()
while IFS= read -r -d '' file; do
  matched_files+=("${file}")
done < <(rg -l "${TAG}" "${ROOT_DIR}" --type-add 'swift:*.swift' -t swift -0)

if [[ ${#matched_files[@]} -eq 0 ]]; then
  echo "No files found with tag: ${TAG}" >&2
  exit 1
fi

sort -u < <(printf "%s\n" "${matched_files[@]}" | sed "s#^${ROOT_DIR}/##") > /tmp/video_review_impacted_files.txt

awk -v list_file="/tmp/video_review_impacted_files.txt" '
  BEGIN {
    while ((getline line < list_file) > 0) {
      files[++count] = line
    }
    close(list_file)
  }
  /^Impacted Files$/ {
    print $0
    in_list = 1
    next
  }
  in_list == 1 {
    if ($0 ~ /^[0-9]+\./) {
      next
    }
    # skip blank line after list
    if ($0 ~ /^$/) {
      for (i = 1; i <= count; i++) {
        printf("%d. %s\n", i, files[i])
      }
      print ""
      in_list = 0
      next
    }
  }
  {
    print $0
  }
  END {
    if (in_list == 1) {
      for (i = 1; i <= count; i++) {
        printf("%d. %s\n", i, files[i])
      }
    }
  }
' "${REQ_FILE}" > "${REQ_FILE}.tmp"

mv "${REQ_FILE}.tmp" "${REQ_FILE}"
rm -f /tmp/video_review_impacted_files.txt
echo "Updated impacted files list in ${REQ_FILE}"
