#!/bin/bash

# Script Vars
REPO_URL="https://github.com/EricTsai83/next-self-host.git"
APP_DIR=~/myapp

# Pull the latest changes from the Git repository
if [ -d "$APP_DIR" ]; then
  echo "Pulling latest changes from the repository..."
  cd $APP_DIR
  # Ensure the remote URL is correct (in case it was cloned from a different repo)
  CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [ "$CURRENT_REMOTE" != "$REPO_URL" ]; then
    echo "Updating remote URL from $CURRENT_REMOTE to $REPO_URL..."
    git remote set-url origin "$REPO_URL"
  fi
  git pull origin main
else
  echo "Cloning repository from $REPO_URL..."
  git clone $REPO_URL $APP_DIR
  cd $APP_DIR
fi

# Build and restart the Docker containers from the app directory (~/myapp)
echo "Rebuilding and restarting Docker containers..."
sudo docker-compose down
sudo docker-compose up --build -d

# Check if Docker Compose started correctly
if ! sudo docker-compose ps | grep "Up"; then
  echo "Docker containers failed to start. Check logs with 'docker-compose logs'."
  exit 1
fi

# Output final message
echo "Update complete. Your Next.js app has been deployed with the latest changes."

