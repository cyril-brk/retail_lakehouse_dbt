#!/usr/bin/env bash
# =============================================================================
# Upload the generated CSVs to a Unity Catalog Volume so setup/03 can COPY INTO.
# Requires the Databricks CLL (v0.292.0+) and a configured profile.
#
# Usage:
#   ./scripts/upload_data_to_volume.sh <PROFILE> <CATALOG>
# Example:
#   ./scripts/upload_data_to_volume.sh fe-vm-vdm retail_lakehouse_dev
# =============================================================================
set -euo pipefail

PROFILE="${1:?Pass a Databricks CLI profile name as arg 1}"
CATALOG="${2:-retail_lakehouse_dbt}"
VOLUME_PATH="/Volumes/${CATALOG}/raw/landing"

echo "Uploading data/*.csv to ${VOLUME_PATH} using profile '${PROFILE}'..."
for f in data/raw_*.csv; do
  echo "  -> $(basename "$f")"
  databricks fs cp "$f" "dbfs:${VOLUME_PATH}/$(basename "$f")" \
    --overwrite --profile "$PROFILE"
done
echo "Done. Now run setup/03_load_raw_copy_into.sql in the SQL editor."
