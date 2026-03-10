#!/bin/bash
# =============================================================================
# ClamAV Daily Scan Script
# Scans files added in the last 24 hours in /mnt/media and /mnt/media2
# =============================================================================

# --- Configuration ---
SCAN_DIRS=("/mnt/media" "/mnt/media2")
LOG_DIR="/var/log/clamav"
LOG_FILE="${LOG_DIR}/daily_scan_$(date +%Y-%m-%d).log"
FRESHCLAM_LOG="${LOG_DIR}/freshclam_$(date +%Y-%m-%d).log"
HOURS_AGO=24  # Files modified/added within the last N hours

# --- Setup ---
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# --- Header ---
log "============================================================"
log " ClamAV Daily Scan Report"
log " Date: $(date '+%A, %B %d, %Y')"
log " Scan targets: ${SCAN_DIRS[*]}"
log " File window: last ${HOURS_AGO} hours"
log "============================================================"

# --- Step 1: Update ClamAV Definitions ---
log ""
log "[1/3] Updating ClamAV virus definitions (freshclam)..."

if ! command -v freshclam &>/dev/null; then
    log "ERROR: freshclam not found. Is ClamAV installed?"
    exit 1
fi

freshclam --log="$FRESHCLAM_LOG" 2>&1 | tee -a "$LOG_FILE"
FRESHCLAM_EXIT=${PIPESTATUS[0]}

if [ "$FRESHCLAM_EXIT" -eq 0 ]; then
    log "Virus definitions updated successfully."
elif [ "$FRESHCLAM_EXIT" -eq 1 ]; then
    log "Virus definitions are already up to date."
else
    log "WARNING: freshclam exited with code $FRESHCLAM_EXIT. Continuing scan with existing definitions."
fi

# --- Step 2: Collect Files Modified in Last 24 Hours ---
log ""
log "[2/3] Collecting files added/modified in the last ${HOURS_AGO} hours..."

TMPFILE=$(mktemp /tmp/clamav_scan_list.XXXXXX)

for DIR in "${SCAN_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
        find "$DIR" -type f -mtime -1 >> "$TMPFILE"
        COUNT=$(find "$DIR" -type f -mtime -1 | wc -l)
        log "  $DIR — $COUNT file(s) found"
    else
        log "  WARNING: Directory '$DIR' does not exist or is not mounted. Skipping."
    fi
done

TOTAL_FILES=$(wc -l < "$TMPFILE")
log "  Total files to scan: $TOTAL_FILES"

# --- Step 3: Run ClamAV Scan ---
log ""
log "[3/3] Starting ClamAV scan..."

if [ "$TOTAL_FILES" -eq 0 ]; then
    log "No files found in the last ${HOURS_AGO} hours. Scan skipped."
    INFECTED=0
    SCAN_EXIT=0
else
    if ! command -v clamscan &>/dev/null; then
        log "ERROR: clamscan not found. Is ClamAV installed?"
        rm -f "$TMPFILE"
        exit 1
    fi

    SCAN_OUTPUT=$(clamscan \
        --file-list="$TMPFILE" \
        --infected \
        --remove=no \
        --recursive \
        --stdout \
        2>&1)
    SCAN_EXIT=$?

    echo "$SCAN_OUTPUT" | tee -a "$LOG_FILE"

    INFECTED=$(echo "$SCAN_OUTPUT" | grep -c "FOUND" || true)
fi

rm -f "$TMPFILE"

# --- Summary ---
log ""
log "============================================================"
log " SCAN SUMMARY"
log "============================================================"
log "  Files scanned   : $TOTAL_FILES"
log "  Infected found  : $INFECTED"
log "  Scan exit code  : $SCAN_EXIT"

if [ "$SCAN_EXIT" -eq 0 ]; then
    log "  Status          : CLEAN — No threats detected."
elif [ "$SCAN_EXIT" -eq 1 ]; then
    log "  Status          : WARNING — Infected file(s) detected! Review log above."
else
    log "  Status          : ERROR — clamscan encountered an error (exit code $SCAN_EXIT)."
fi

log "  Log saved to    : $LOG_FILE"
log "============================================================"
log ""

exit $SCAN_EXIT