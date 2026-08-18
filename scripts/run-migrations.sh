#!/bin/bash

set -e

echo "=============================================="
echo "        DATABASE MIGRATION RUNNER"
echo "=============================================="

# ==================================================
# Configuration
# ==================================================

DB_CONTAINER="zerodowntime-postgres"
DB_USER="appuser"
DB_NAME="zerodowntime"

MIGRATIONS_DIR="database/migrations"

# ==================================================
# Always run from project root
# ==================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo ""
echo "Project root:"
echo "$PROJECT_ROOT"

echo ""
echo "Migrations directory:"
echo "$MIGRATIONS_DIR"

# ==================================================
# Check migration directory
# ==================================================

if [ ! -d "$MIGRATIONS_DIR" ]; then
    echo ""
    echo "ERROR: Migration directory does not exist:"
    echo "$MIGRATIONS_DIR"
    exit 1
fi

# ==================================================
# Check PostgreSQL container exists
# ==================================================

echo ""
echo "=============================================="
echo "1. Checking PostgreSQL container"
echo "=============================================="

if ! docker container inspect "$DB_CONTAINER" >/dev/null 2>&1; then
    echo "ERROR: PostgreSQL container '$DB_CONTAINER' does not exist."
    echo ""
    echo "Check available containers with:"
    echo "docker ps -a"
    exit 1
fi

echo "PostgreSQL container exists."

# ==================================================
# Check PostgreSQL container is running
# ==================================================

if [ "$(docker inspect -f '{{.State.Running}}' "$DB_CONTAINER")" != "true" ]; then
    echo ""
    echo "PostgreSQL container is not running."
    echo "Starting container..."

    docker start "$DB_CONTAINER" >/dev/null

    echo "PostgreSQL container started."
fi

# ==================================================
# Check database readiness
# ==================================================

echo ""
echo "=============================================="
echo "2. Checking database readiness"
echo "=============================================="

MAX_RETRIES=30
RETRY_COUNT=0

until MSYS_NO_PATHCONV=1 docker exec \
    "$DB_CONTAINER" \
    pg_isready \
    -U "$DB_USER" \
    -d "$DB_NAME" >/dev/null 2>&1
do

    RETRY_COUNT=$((RETRY_COUNT + 1))

    if [ "$RETRY_COUNT" -ge "$MAX_RETRIES" ]; then
        echo ""
        echo "ERROR: PostgreSQL did not become ready."
        echo ""
        echo "Check logs with:"
        echo "docker logs $DB_CONTAINER"
        exit 1
    fi

    echo "Database not ready yet... retry $RETRY_COUNT/$MAX_RETRIES"

    sleep 2
done

echo "Database is ready."

# ==================================================
# Create migration tracking table
# ==================================================

echo ""
echo "=============================================="
echo "3. Creating migration tracking table"
echo "=============================================="

MSYS_NO_PATHCONV=1 docker exec \
    "$DB_CONTAINER" \
    psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v ON_ERROR_STOP=1 \
    -c "
CREATE TABLE IF NOT EXISTS schema_migrations (
    version VARCHAR(255) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"

echo "schema_migrations table is ready."

# ==================================================
# Find migration files
# ==================================================

echo ""
echo "=============================================="
echo "4. Finding migration files"
echo "=============================================="

MIGRATION_FILES=()

while IFS= read -r -d '' file; do
    MIGRATION_FILES+=("$file")
done < <(find "$MIGRATIONS_DIR" -maxdepth 1 -type f -name "*.sql" -print0 | sort -z)

if [ "${#MIGRATION_FILES[@]}" -eq 0 ]; then
    echo ""
    echo "ERROR: No .sql migration files found."
    echo ""
    echo "Expected location:"
    echo "$MIGRATIONS_DIR"

    exit 1
fi

echo "Found ${#MIGRATION_FILES[@]} migration file(s)."

# ==================================================
# Apply migrations
# ==================================================

echo ""
echo "=============================================="
echo "5. Processing migrations"
echo "=============================================="

for migration in "${MIGRATION_FILES[@]}"
do

    filename="$(basename "$migration")"

    echo ""
    echo "----------------------------------------------"
    echo "Migration: $filename"
    echo "----------------------------------------------"

    # ------------------------------------------------
    # Check migration status
    # ------------------------------------------------

    echo "Checking migration status..."

    migration_exists=$(
        MSYS_NO_PATHCONV=1 docker exec \
            "$DB_CONTAINER" \
            psql \
            -U "$DB_USER" \
            -d "$DB_NAME" \
            -tAc \
            "SELECT 1 FROM schema_migrations WHERE version = '$filename';" \
            | tr -d '[:space:]'
    )

    if [ "$migration_exists" = "1" ]; then

        echo "Migration already applied."
        echo "Skipping: $filename"

        continue
    fi

    echo "Migration not applied."

    # ------------------------------------------------
    # Copy migration into PostgreSQL container
    # ------------------------------------------------

    echo ""
    echo "Copying $filename into PostgreSQL container..."

    docker cp \
        "$migration" \
        "$DB_CONTAINER:/tmp/$filename"

    echo "Successfully copied $filename."

    # ------------------------------------------------
    # Verify file exists inside container
    # ------------------------------------------------

    echo ""
    echo "Verifying migration file inside container..."

    if ! MSYS_NO_PATHCONV=1 docker exec \
        "$DB_CONTAINER" \
        test -f "/tmp/$filename"
    then

        echo "ERROR: Migration file was not found inside container:"
        echo "/tmp/$filename"

        exit 1
    fi

    echo "Migration file exists inside container."

    # ------------------------------------------------
    # Execute migration
    # ------------------------------------------------

    echo ""
    echo "Executing $filename..."

    if MSYS_NO_PATHCONV=1 docker exec \
        "$DB_CONTAINER" \
        psql \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -v ON_ERROR_STOP=1 \
        -f "/tmp/$filename"
    then

        echo "Migration executed successfully."

    else

        echo ""
        echo "=============================================="
        echo "ERROR: Migration failed"
        echo "=============================================="

        echo "Migration:"
        echo "$filename"

        echo ""
        echo "The migration has NOT been recorded."

        echo ""
        echo "Temporary migration file remains inside container:"
        echo "/tmp/$filename"

        exit 1
    fi

    # ------------------------------------------------
    # Record migration
    # ------------------------------------------------

    echo ""
    echo "Recording migration..."

    MSYS_NO_PATHCONV=1 docker exec \
        "$DB_CONTAINER" \
        psql \
        -U "$DB_USER" \
        -d "$DB_NAME" \
        -v ON_ERROR_STOP=1 \
        -c "
INSERT INTO schema_migrations (version)
VALUES ('$filename');
"

    echo "Migration recorded successfully."

    # ------------------------------------------------
    # Remove temporary file
    # ------------------------------------------------

    echo ""
    echo "Cleaning temporary migration file..."

    MSYS_NO_PATHCONV=1 docker exec \
        "$DB_CONTAINER" \
        rm -f "/tmp/$filename"

    echo "Temporary file removed."

    echo ""
    echo "Migration completed successfully:"
    echo "$filename"

done

# ==================================================
# Final verification
# ==================================================

echo ""
echo "=============================================="
echo "6. Final migration verification"
echo "=============================================="

echo ""
echo "Applied migrations:"

MSYS_NO_PATHCONV=1 docker exec \
    "$DB_CONTAINER" \
    psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "
SELECT
    version,
    applied_at
FROM schema_migrations
ORDER BY applied_at;
"

# ==================================================
# Final database check
# ==================================================

echo ""
echo "=============================================="
echo "7. Database verification"
echo "=============================================="

MSYS_NO_PATHCONV=1 docker exec \
    "$DB_CONTAINER" \
    psql \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -c "\dt"

# ==================================================
# Success
# ==================================================

echo ""
echo "=============================================="
echo "     ALL MIGRATIONS COMPLETED SUCCESSFULLY"
echo "=============================================="

echo ""
echo "Database:"
echo "  Container : $DB_CONTAINER"
echo "  Database  : $DB_NAME"
echo "  User      : $DB_USER"

echo ""
echo "Migration directory:"
echo "  $MIGRATIONS_DIR"

echo ""
echo "Migration process completed successfully."