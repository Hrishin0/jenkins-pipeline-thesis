# Base image
FROM debian:bookworm-slim

# Set working directory
WORKDIR /app

# Copy all files to the container
COPY . .

# No extra steps since this is for scanning only
