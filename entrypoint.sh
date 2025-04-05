#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until nc -z localhost 5432; do
  echo "PostgreSQL not available yet - sleeping"
  sleep 2
done
echo "PostgreSQL is up - executing initialization"

# Check if Medusa is already initialized by looking for package.json with medusa dependency
if [ ! -f "package.json" ] || ! grep -q "@medusajs/medusa" "package.json"; then
  echo "Creating new Medusa application..."
  # Initialize a new Medusa project in the current directory
  npx @medusajs/medusa-cli@latest new -y --skip-db --db-url=$DATABASE_URL .
else
  echo "Medusa application already exists, running migrations..."
  npx medusa migrations run
fi

# Seed data if needed (only on first run)
if [ "$SEED_DATABASE" = "true" ] && [ ! -f ".seed-completed" ]; then
  echo "Seeding database..."
  npx medusa seed --seed-file=./data/seed.json || echo "Seeding failed, continuing anyway"
  touch .seed-completed
fi

# Start the Medusa server
echo "Starting Medusa server..."
npx medusa start