#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until nc -z localhost 5432; do
  echo "PostgreSQL not available yet - sleeping"
  sleep 2
done
echo "PostgreSQL is up - executing initialization"

# Check if Medusa is already initialized by looking for medusa-config.js
if [ ! -f "medusa-config.js" ]; then
  echo "Creating new Medusa application..."
  # Initialize using medusa-cli new command with the --directory flag to specify current directory
  npx @medusajs/medusa-cli new --skip-db --db-url=$DATABASE_URL --directory=medusa --seed
else
  echo "Medusa application already exists, running migrations..."
  npx medusa migrations run
fi

# Seed data if needed (only on first run)
if [ "$SEED_DATABASE" = "true" ] && [ ! -f ".seed-completed" ]; then
  echo "Seeding database with custom data..."
  npx medusa seed --seed-file=./data/seed.json || echo "Seeding failed, continuing anyway"
  touch .seed-completed
fi

# Start the Medusa server
echo "Starting Medusa server..."
npx medusa start