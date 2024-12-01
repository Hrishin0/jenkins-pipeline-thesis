# Base image
FROM python:3.10-slim-bullseye
# Set working directory
WORKDIR /app

# Copy all files to the container
COPY . .

# No extra steps since this is for scanning only
