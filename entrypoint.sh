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
if [ ! -d "medusa-backend" ]; then
  echo "Creating new Medusa application..."
  # Use expect to answer "no" to the storefront question automatically
  apt-get update && apt-get install -y expect
  
  # Create expect script to handle interactive prompts
  cat > create-medusa.exp << 'EXPEOF'
  #!/usr/bin/expect -f
  set timeout -1
  spawn npx create-medusa-app@latest medusa-backend --skip-db --db-url "$env(DATABASE_URL)" --no-browser
  expect "Would you like to create the Next.js storefront? You can also create it later (y/N)"
  send "n\r"
  expect eof
  EXPEOF
  
  chmod +x create-medusa.exp
  ./create-medusa.exp
  
  # Run migrations
  cd medusa-backend
  npx medusa migrations run
else
  echo "Medusa application already exists, running migrations..."
  cd medusa-backend
  npx medusa migrations run
fi

# Seed data if needed (only on first run)
if [ "$SEED_DATABASE" = "true" ] && [ ! -f ".seed-completed" ]; then
  echo "Seeding database with custom data..."
  cd medusa-backend
  npx medusa seed --seed-file=../data/seed.json || echo "Seeding failed, continuing anyway"
  cd ..
  touch .seed-completed
fi

# Start the Medusa server
echo "Starting Medusa server..."
# Use correct host parameter to make it accessible from outside the container
cd medusa-backend
npx medusa start --host=0.0.0.0