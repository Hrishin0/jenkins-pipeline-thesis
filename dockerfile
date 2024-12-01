# Base image
FROM python:3.13-slim-bookworm
# Set working directory
WORKDIR /app

# Copy all files to the container
COPY . .

# No extra steps since this is for scanning only
