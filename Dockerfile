# Use the official Alpine image as the base image
FROM alpine:latest

# Install GLPK and its dependencies
RUN apk update && \
    apk add --no-cache glpk glpk-dev

# Set the working directory
WORKDIR /opt

# Copy the current directory contents into the container at /app
COPY . /opt

# Ensure all .sh files have execution permissions
RUN find /opt -name "*.sh" -exec chmod +x {} \;
