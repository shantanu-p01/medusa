#!/bin/bash
set -e

# Wait for PostgreSQL to be ready
echo "Waiting for PostgreSQL..."
until nc -z localhost 5432; do
  echo "PostgreSQL not available yet - sleeping"
  sleep 2
done
echo "PostgreSQL is up - executing initialization"

# Check if Medusa is already initialized
if [ ! -f "medusa-config.js" ]; then
  echo "Creating new Medusa application..."
  # Create a new Medusa project in the current directory with the correct flags
  npx @medusajs/medusa-cli new medusa --skip-db --useDefaults
  
  # Update database configuration manually since we can't pass db-url
  if [ -f "medusa-config.js" ]; then
    sed -i 's|type: "sqlite"|type: "postgres"|g' medusa-config.js
    sed -i 's|url: "postgres://localhost/medusa-store"|url: "'"$DATABASE_URL"'"|g' medusa-config.js
  fi
  
  # Run migrations
  npx medusa migrations run
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
# Use correct host parameter to make it accessible from outside the container
npx medusa start --host=0.0.0.0