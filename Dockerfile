# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=16.14.0
FROM node:${NODE_VERSION}-slim as base

LABEL fly_launch_runtime="Next.js"

# Next.js app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV=production

# Install SQLite & LiteFS dependencies
RUN apt-get update -qq && \
    apt-get install -y ca-certificates fuse3 sqlite3


# Throw-away build stage to reduce size of final image
FROM base as build

# Install packages needed to build node modules; SQLite & LiteFS dependencies
RUN apt-get update -qq && \
    apt-get install -y python pkg-config build-essential

# Install node modules
COPY --link package-lock.json package.json ./
RUN npm ci --include=dev

# Copy application code
COPY --link . .

# Build application
RUN npm run build

# Remove development dependencies
RUN npm prune --omit=dev


# Final stage for app image
FROM base

# Copy built application
COPY --from=build /app /app

# Install LiteFS binary
COPY --from=flyio/litefs:0.5 /usr/local/bin/litefs /usr/local/bin/litefs
ADD litefs.yml /etc/litefs.yml

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000

ENTRYPOINT litefs mount
