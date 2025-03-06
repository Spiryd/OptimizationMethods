# Use the official Alpine image as the base image
FROM alpine:latest

# Install GLPK and its dependencies
RUN apk update && \
    apk add --no-cache glpk glpk-dev

# Set the working directory
WORKDIR /l1

# Copy the current directory contents into the container at /app
COPY /l1 /l1
