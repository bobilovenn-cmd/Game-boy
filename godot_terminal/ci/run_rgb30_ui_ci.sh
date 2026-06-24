#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$ROOT"

./ci/check_repository_hygiene.sh
./ci/check_archived_ant_removed.sh
./tests/run_all.sh
./ci/export_rgb30_arm64.sh
