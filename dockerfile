FROM node:20

WORKDIR /app

# Install required dependencies
RUN apt-get update && apt-get install -y python3 build-essential netcat-traditional

# Install global Medusa CLI
RUN npm install -g @medusajs/medusa-cli

# Set environment variables
ENV NODE_ENV=production
ENV PORT=9000
ENV DATABASE_TYPE=postgres
ENV DATABASE_URL=postgres://medusa:medusa@localhost:5432/medusa
ENV COOKIE_SECRET=supersecret
ENV JWT_SECRET=supersecret

# Expose the port the app runs on
EXPOSE 9000

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]