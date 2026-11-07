#!/usr/bin/env bash
# Asserts how many actions a Bazel build executed and that all of them used the expected spawn strategy.
set -euo pipefail

if [[ $# -ne 3 ]]; then
  echo "usage: $0 <build-log> <executed> <strategy-glob>" >&2
  exit 2
fi

log="$1" want_executed="$2" want_strategy="$3"
executed=0 strategy_count=0

summary="$(grep -E '^INFO: [0-9]+ process(es)?:' "${log}" | tail -1)"
[[ -n "${summary}" ]] || { echo "FAIL: no process summary found in ${log}"; exit 1; }
echo "${summary}"

# Strips the "INFO: N processes: " prefix and the trailing period, then tallies each category.
while IFS= read -r entry; do
  count="${entry%% *}"
  label="${entry#* }"
  case "${label}" in
    internal | *"cache hit") ;;
    # Leaves the strategy unquoted so it can be a glob such as "*-sandbox".
    ${want_strategy}) executed=$((executed + count)) strategy_count=$((strategy_count + count)) ;;
    *) executed=$((executed + count)) ;;
  esac
done < <(echo "${summary}" | sed -E 's/^INFO: [0-9]+ process(es)?: //; s/\.$//' | tr ',' '\n' | sed -E 's/^ +//')

echo "executed=${executed} ${want_strategy}=${strategy_count}"
if [[ "${executed}" != "${want_executed}" || "${strategy_count}" != "${want_executed}" ]]; then
  echo "FAIL: expected ${want_executed} actions executed with the ${want_strategy} strategy"
  exit 1
fi
echo "PASS"
