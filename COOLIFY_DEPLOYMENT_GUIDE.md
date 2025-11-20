# Rails 8 Deployment Guide for Coolify

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Third-Party Services Setup](#third-party-services-setup)
4. [Environment Variables](#environment-variables)
5. [Architecture](#architecture)
6. [Step-by-Step Deployment](#step-by-step-deployment)
7. [Configuration Files](#configuration-files)
8. [Logging Configuration](#logging-configuration)
9. [Post-Deployment Verification](#post-deployment-verification)
10. [Common Issues & Solutions](#common-issues--solutions)
11. [Rails 8 Specific: Solid Libraries](#rails-8-specific-solid-libraries)
12. [Performance Optimization](#performance-optimization)
13. [Scaling](#scaling)
14. [Backup Strategy](#backup-strategy)
15. [Security Considerations](#security-considerations)
16. [Troubleshooting](#troubleshooting)
17. [Deployment Checklist](#deployment-checklist)

---

## Overview

This guide documents the complete process for deploying a Rails 8 application to **Coolify**, a self-hosted Platform-as-a-Service (PaaS). It covers all configurations, gotchas, and solutions discovered during a real-world deployment of the vacanciesAT application.

### What You'll Learn
- How to configure Rails 8's Solid Cache/Queue/Cable for single-database deployment
- Setting up Docker with BuildKit optimizations
- Configuring Traefik reverse proxy via Docker labels
- Handling PORT configuration between Thruster, Puma, and Coolify
- Managing secrets with `.env` files (no Rails credentials)
- Optimizing Docker builds for faster deployments

### Technology Stack
- **Rails**: 8.0.2
- **Ruby**: 3.4.2
- **Database**: PostgreSQL
- **Web Server**: Puma (cluster mode)
- **Reverse Proxy**: Thruster (Rails 8 built-in)
- **Cache/Queue/Cable**: Solid libraries (database-backed)
- **Container Orchestration**: Docker Compose
- **External Routing**: Traefik (managed by Coolify)
- **SSL**: Let's Encrypt (via Traefik)
- **File Storage**: Cloudflare R2 (ActiveStorage)
- **Email**: Postmark
- **Payments**: Stripe
- **PDF Generation**: Chrome/Puppeteer (Grover gem)

---

## Prerequisites

### Required Knowledge
- Basic Docker and Docker Compose
- Rails fundamentals
- Git workflow
- Basic networking (ports, proxies)

### Required Tools
- Coolify instance running
- GitHub account (for private repositories)
- PostgreSQL database (via Coolify or external)
- Custom domain (optional, but recommended)

### Environment Setup
Your Rails app should:
- Be on Rails 8.x
- Use PostgreSQL (not SQLite)
- Have a `Dockerfile` and `docker-compose.yml`
- Use environment variables for secrets (`.env` approach)

---

## Third-Party Services Setup

Before deploying, configure these external services:

### 1. Postmark (Email Delivery)
1. Sign up at https://postmarkapp.com/
2. Create a server
3. Get your **Server API Token**
4. Add and verify your sending domain
5. Save token for `POSTMARK_API_TOKEN` environment variable

### 2. Cloudflare R2 (File Storage)
1. Go to Cloudflare Dashboard → R2
2. Create a bucket for production (e.g., `vacanciesat-production`)
3. Generate API keys:
   - Click "Manage R2 API Tokens"
   - Create token with "Admin Read & Write" permissions
   - Save **Access Key ID** and **Secret Access Key**
4. Note the **endpoint URL** (format: `https://<account-id>.r2.cloudflarestorage.com`)
5. **Configure CORS** for direct uploads (see [DATABASE_EXPORT_IMPORT_GUIDE.md](./DATABASE_EXPORT_IMPORT_GUIDE.md)):
   ```json
   {
     "AllowedOrigins": ["https://vacancies.at", "https://coolify.vacancies.at"],
     "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
     "AllowedHeaders": ["*"],
     "ExposeHeaders": ["ETag"],
     "MaxAgeSeconds": 3600
   }
   ```

### 3. Stripe (Payments)
1. Sign up at https://stripe.com/
2. Get API keys from Dashboard → Developers → API keys:
   - **Secret key** (sk_live_...)
   - **Publishable key** (pk_live_...)
3. Configure webhook:
   - Go to Developers → Webhooks
   - Add endpoint: `https://vacancies.at/webhooks/payments/stripe`
   - Select events: `checkout.session.completed`, `payment_intent.succeeded`, `payment_intent.payment_failed`
   - Save **webhook signing secret** (whsec_...)

### 4. AI API Keys (Optional)
- **OpenAI**: Get from https://platform.openai.com/ → API keys
- **Anthropic**: Get from https://console.anthropic.com/ → API keys

---

## Environment Variables

### Critical Variables (Minimum Required)

```bash
# Database
DATABASE_URL=postgresql://user:password@host:5432/database
VACANCIES_DATABASE_PASSWORD=your_database_password

# Rails Security (generate with: rails secret)
RAILS_MASTER_KEY=your_master_key_from_config_master_key
ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=generate_with_rails_secret
ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=generate_with_rails_secret
ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=generate_with_rails_secret

# Application
APP_DOMAIN=vacancies.at
APP_URL=https://vacancies.at
APP_RESET_SECRET=generate_with_rails_secret

# Email
POSTMARK_API_TOKEN=your_postmark_server_api_token

# File Storage
CLOUDFLARE_R2_ACCESS_KEY_ID=your_r2_access_key
CLOUDFLARE_R2_SECRET_ACCESS_KEY=your_r2_secret_key
CLOUDFLARE_R2_ENDPOINT=https://your-account-id.r2.cloudflarestorage.com
CLOUDFLARE_R2_BUCKET=vacanciesat-production

# Payments
STRIPE_SECRET_KEY=sk_live_...
STRIPE_PUBLISHABLE_KEY=pk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Mission Control
MISSION_CONTROL_PASSWORD=generate_strong_password
```

### Optional Variables

```bash
# AI Services
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Analytics
GOOGLE_ANALYTICS_ID=G-...

# Monitoring
SENTRY_DSN=https://...@sentry.io/...

# Feature Flags
ENABLE_AI_FEATURES=true
ENABLE_PAYMENTS=true
```

### Generating Secrets

```bash
# Generate Rails secrets
rails secret

# Generate strong passwords (macOS)
openssl rand -base64 32

# Or use password manager (1Password, Bitwarden, etc.)
```

---

## Architecture

### Request Flow
```
Internet
  ↓
Traefik (:443 SSL termination, :80 HTTP)
  ↓
Coolify Docker Network
  ↓
Web Container
  ↓
Thruster (:80 → HTTP/2 proxy)
  ↓
Puma (:3000 → Rails app)
  ↓
PostgreSQL (all tables: app + Solid Cache/Queue/Cable)
```

### Container Architecture
```
services:
  web       → Runs Thruster + Puma + Rails
  worker    → Runs Solid Queue job processor

External:
  PostgreSQL → Managed by Coolify or external service
  Traefik    → Managed by Coolify (automatic)
```

### Port Configuration (CRITICAL)
- **Traefik**: Routes to port 80 (configured via Docker labels)
- **Thruster**: Listens on port 80 (`THRUSTER_HTTP_PORT=80`)
- **Puma**: Listens on port 3000 (`THRUSTER_TARGET_PORT=3000`)
- **Environment Variable**: `PORT=80` (for Coolify routing)

**Common Mistake**: Setting `PORT=3000` causes "no available server" error because Traefik can't reach Thruster.

---

## Step-by-Step Deployment

### Phase 1: Prepare Your Rails App

#### 1.1 Configure Database for Single Instance
Rails 8 ships with multi-database configuration for Solid libraries. For simpler deployments, consolidate to a single database.

**Edit `config/database.yml`**:
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV.fetch("DATABASE_POOL_SIZE") { 30 } %>
  checkout_timeout: 5
  idle_timeout: <%= ENV.fetch("DATABASE_IDLE_TIMEOUT") { 300 } %>
```

**Edit `config/cache.yml`**:
```yaml
production:
  primary_store:
    adapter: solid_cache
    # DO NOT include: database: cache
  secondary_store:
    adapter: memory
    size: 10485760
  store_options:
    max_age: 86400
    namespace: cache
    error_handler: ->(_e) {}
```

**Edit `config/cable.yml`**:
```yaml
production:
  adapter: solid_cable
  # DO NOT include: connects_to database configuration
  polling_interval: 0.1.seconds
  message_retention: 1.day
```

**Edit `config/queue.yml`**:
```yaml
production:
  # DO NOT include: connects_to database configuration
  dispatchers:
    - polling_interval: 1
      batch_size: 500
      concurrency_maintenance_interval: 600
  workers:
    - queues: "*"
      threads: 3
      processes: <%= ENV.fetch("JOB_CONCURRENCY") { 1 } %>
      polling_interval: 0.1
```

**Edit `config/environments/production.rb`**:
```ruby
config.active_job.queue_adapter = :solid_queue
# DO NOT include: config.solid_queue.connects_to = { database: { writing: :queue } }
```

#### 1.2 Create Solid Table Migrations
Create three migration files with idempotency checks.

**`db/migrate/YYYYMMDDHHMMSS_create_solid_cache.rb`**:
```ruby
class CreateSolidCache < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_cache_entries)

    create_table :solid_cache_entries do |t|
      t.binary :key, limit: 1024, null: false
      t.binary :value, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :key_hash, null: false
      t.integer :byte_size, null: false

      t.index :byte_size
      t.index [:key_hash, :byte_size]
      t.index :key_hash, unique: true
    end
  end
end
```

**`db/migrate/YYYYMMDDHHMMSS_create_solid_queue.rb`**:
```ruby
class CreateSolidQueue < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_queue_jobs)

    create_table :solid_queue_jobs do |t|
      t.string :queue_name, null: false
      t.string :class_name, null: false
      t.text :arguments
      t.integer :priority, default: 0, null: false
      t.string :active_job_id
      t.datetime :scheduled_at
      t.datetime :finished_at
      t.string :concurrency_key
      t.timestamps

      t.index [:queue_name, :finished_at], name: "index_solid_queue_jobs_for_filtering"
      t.index [:scheduled_at, :finished_at], name: "index_solid_queue_jobs_for_alerting"
      t.index :class_name
      t.index :active_job_id, unique: true
      t.index :concurrency_key
    end

    create_table :solid_queue_scheduled_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.datetime :scheduled_at, null: false
      t.timestamps

      t.index [:scheduled_at, :priority, :job_id], name: "index_solid_queue_scheduled_executions"
    end

    create_table :solid_queue_ready_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.timestamps

      t.index [:priority, :job_id], name: "index_solid_queue_ready_executions"
      t.index :queue_name
    end

    create_table :solid_queue_claimed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.bigint :process_id
      t.timestamps

      t.index [:process_id, :job_id]
    end

    create_table :solid_queue_blocked_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.string :queue_name, null: false
      t.integer :priority, default: 0, null: false
      t.string :concurrency_key, null: false
      t.datetime :expires_at, null: false
      t.timestamps

      t.index [:expires_at, :concurrency_key], name: "index_solid_queue_blocked_executions"
    end

    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.text :error
      t.integer :attempts, default: 0, null: false
      t.timestamps

      t.index [:job_id, :attempts]
    end

    create_table :solid_queue_pauses do |t|
      t.string :queue_name, null: false
      t.timestamps

      t.index :queue_name, unique: true
    end

    create_table :solid_queue_processes do |t|
      t.string :kind, null: false
      t.datetime :last_heartbeat_at, null: false
      t.bigint :supervisor_id
      t.integer :pid, null: false
      t.string :hostname
      t.text :metadata
      t.timestamps

      t.index :last_heartbeat_at
      t.index [:kind, :last_heartbeat_at]
    end

    create_table :solid_queue_semaphores do |t|
      t.string :key, null: false
      t.integer :value, default: 1, null: false
      t.datetime :expires_at
      t.timestamps

      t.index [:key, :value], unique: true
      t.index :expires_at
    end
  end
end
```

**`db/migrate/YYYYMMDDHHMMSS_create_solid_cable.rb`**:
```ruby
class CreateSolidCable < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_cable_messages)

    create_table :solid_cable_messages do |t|
      t.binary :channel, limit: 1024, null: false
      t.binary :payload, limit: 536870912, null: false
      t.datetime :created_at, null: false
      t.bigint :channel_hash, null: false

      t.index :channel
      t.index :channel_hash
      t.index :created_at
    end
  end
end
```

#### 1.3 Configure Puma for Docker
**Edit `config/puma.rb`**:
```ruby
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)

# CRITICAL: Bind to 0.0.0.0 for Docker networking
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

preload_app!

plugin :tmp_restart
```

**Why `0.0.0.0` is critical**: Docker containers need to bind to all network interfaces, not just `127.0.0.1` (localhost).

#### 1.4 Remove Rails Credentials (If Using .env Only)
If your app uses `.env` files instead of Rails encrypted credentials:

```bash
rm config/credentials.yml.enc
rm config/master.key  # if exists
```

**Update `config/application.rb`**:
```ruby
# Disable credentials loading
config.credentials.content_path = nil
```

This prevents `RAILS_MASTER_KEY` errors when the file doesn't exist.

---

### Phase 2: Docker Configuration

#### 2.1 Create Optimized Dockerfile

**`Dockerfile`** (with BuildKit optimizations):
```dockerfile
# syntax=docker/dockerfile:1
# check=skip=SecretsUsedInArgOrEnv

ARG RUBY_VERSION=3.4.2
ARG NODE_VERSION=20.18.1

# Stage 1: Get Node.js from official image
FROM node:${NODE_VERSION}-slim AS node

# Stage 2: Base Ruby image
FROM docker.io/library/ruby:${RUBY_VERSION}-slim AS base

# Copy Node.js from official image (faster than installing)
COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
RUN ln -s /usr/local/bin/node /usr/local/bin/nodejs && \
    ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm && \
    ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx

# Rails app lives here
WORKDIR /rails

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test"

# Install base packages with BuildKit cache mount
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        curl \
        libjemalloc2 \
        libvips \
        postgresql-client \
        git

# Stage 3: Build stage
FROM base AS build

# Install build packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
        build-essential \
        libpq-dev \
        pkg-config

# Copy Gemfile and install gems
COPY Gemfile Gemfile.lock ./

# Configure Git to use HTTPS for GitHub (for private gems)
RUN git config --global url."https://github.com/".insteadOf git@github.com: && \
    git config --global url."https://".insteadOf git://

# Install gems with cache mount
RUN --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    --mount=type=secret,id=github_token \
    if [ -f /run/secrets/github_token ]; then \
      BUNDLE_GITHUB__COM="x-access-token:$(cat /run/secrets/github_token)" bundle install; \
    else \
      bundle install; \
    fi && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Copy application code
COPY . .

# Install JavaScript dependencies
RUN --mount=type=cache,target=/rails/node_modules,sharing=locked \
    npm install

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompile assets with dummy SECRET_KEY_BASE
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile

# Stage 4: Final production image
FROM base

# Copy built artifacts from build stage
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-privileged user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp
USER 1000:1000

# Entrypoint prepares the database
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Environment variables for Thruster
ENV THRUSTER_HTTP_PORT=80 \
    THRUSTER_TARGET_PORT=3000

# Expose port 80 for Traefik routing
EXPOSE 80

# Start server via Thruster
CMD ["./bin/thrust", "./bin/rails", "server"]
```

**Key optimizations**:
- **BuildKit cache mounts**: Speeds up rebuilds by caching apt, bundler, npm
- **Multi-stage build**: Reduces final image size by excluding build tools
- **Node.js from official image**: Faster than installing via package manager
- **SECRET_KEY_BASE_DUMMY**: Allows asset precompilation without real secrets

#### 2.2 Create docker-compose.yml with Traefik Labels

**`docker-compose.yml`**:
```yaml
version: "3.8"

services:
  web:
    build:
      context: .
      dockerfile: Dockerfile

    environment:
      # CRITICAL: Set PORT to 80 for Traefik routing
      PORT: "80"

      # Database
      DATABASE_URL: ${DATABASE_URL}

      # Rails
      RAILS_ENV: production
      RAILS_LOG_LEVEL: ${RAILS_LOG_LEVEL:-info}
      RAILS_SERVE_STATIC_FILES: "true"
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}

      # Performance
      RAILS_MAX_THREADS: ${RAILS_MAX_THREADS:-5}
      WEB_CONCURRENCY: ${WEB_CONCURRENCY:-2}
      DATABASE_POOL_SIZE: ${DATABASE_POOL_SIZE:-30}

      # Job processing
      JOB_CONCURRENCY: ${JOB_CONCURRENCY:-1}

    # CRITICAL: Traefik labels for service discovery
    labels:
      # Enable Traefik
      - "traefik.enable=true"

      # HTTPS router
      - "traefik.http.routers.vacancies-web.rule=Host(`coolify.vacancies.at`) || Host(`vacancies.at`) || Host(`www.vacancies.at`)"
      - "traefik.http.routers.vacancies-web.entrypoints=websecure"
      - "traefik.http.routers.vacancies-web.tls=true"
      - "traefik.http.routers.vacancies-web.tls.certresolver=letsencrypt"

      # Load balancer (tell Traefik which port to use)
      - "traefik.http.services.vacancies-web.loadbalancer.server.port=80"

      # HTTP router (redirect to HTTPS)
      - "traefik.http.routers.vacancies-web-http.rule=Host(`coolify.vacancies.at`) || Host(`vacancies.at`) || Host(`www.vacancies.at`)"
      - "traefik.http.routers.vacancies-web-http.entrypoints=web"
      - "traefik.http.routers.vacancies-web-http.middlewares=redirect-to-https"

      # HTTPS redirect middleware
      - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"

    networks:
      - coolify

    depends_on:
      - worker

    restart: unless-stopped

  worker:
    build:
      context: .
      dockerfile: Dockerfile

    command: ["./bin/jobs"]

    environment:
      DATABASE_URL: ${DATABASE_URL}
      RAILS_ENV: production
      RAILS_LOG_LEVEL: ${RAILS_LOG_LEVEL:-info}
      SECRET_KEY_BASE: ${SECRET_KEY_BASE}
      JOB_CONCURRENCY: ${JOB_CONCURRENCY:-1}

    networks:
      - coolify

    restart: unless-stopped

networks:
  coolify:
    external: true
    name: coolify
```

**Critical configurations explained**:

1. **`PORT: "80"`**: Must match Thruster's listen port for Traefik routing
2. **Traefik labels**: Required for Coolify's reverse proxy to discover your service
3. **`traefik.http.services.*.loadbalancer.server.port=80`**: Tells Traefik to route to port 80
4. **`networks: coolify`**: Connects to Coolify's external Docker network
5. **Multiple domain hosts**: Supports www, apex, and subdomain routing
6. **Automatic HTTPS**: Let's Encrypt via `tls.certresolver=letsencrypt`

#### 2.3 Create Docker Entrypoint Script

**`bin/docker-entrypoint`**:
```bash
#!/bin/bash -e

# Enable jemalloc for reduced memory usage and latency
if [ -z "${LD_PRELOAD+x}" ]; then
    LD_PRELOAD=$(find /usr/lib -name libjemalloc.so.2 -print -quit)
    export LD_PRELOAD
fi

# If running the rails server then create or migrate existing database
if [ "${@: -2:1}" == "./bin/rails" ] && [ "${@: -1:1}" == "server" ]; then
  echo "========================================="
  echo "PREPARING DATABASE (PRIMARY + SOLID CACHE/QUEUE/CABLE)"
  echo "========================================="
  ./bin/rails db:prepare

  if [ $? -eq 0 ]; then
    echo "✓ Database prepared successfully"
  else
    echo "✗ Database preparation failed"
    exit 1
  fi
  echo "========================================="
  echo ""
fi

# If running the jobs worker, wait for database to be ready
if [ "${1}" == "./bin/jobs" ]; then
  echo "Waiting for database to be ready..."
  until ./bin/rails runner "ActiveRecord::Base.connection.execute('SELECT 1')" &> /dev/null; do
    echo "Database not ready, waiting..."
    sleep 2
  done
  echo "Database ready!"
fi

exec "${@}"
```

**Make it executable**:
```bash
chmod +x bin/docker-entrypoint
```

**What it does**:
- Enables jemalloc for better memory management
- Runs `db:prepare` before starting web server (creates tables if needed, runs pending migrations)
- Waits for database before starting worker process
- Provides clear logging for debugging

#### 2.4 Create Procfile (Optional, for local development)

**`Procfile`**:
```
web: bin/rails server
worker: bin/jobs
```

This is useful for testing locally with tools like Overmind or Foreman.

---

### Phase 3: Coolify Configuration

#### 3.1 Create PostgreSQL Database in Coolify

1. Go to Coolify dashboard
2. Click **+ New Resource** → **Database** → **PostgreSQL**
3. Configure:
   - **Name**: `vacancies-postgres` (or your app name)
   - **PostgreSQL version**: 16 (or latest)
   - **Initial database**: `vacancies_production`
   - **Username**: `postgres` (default)
   - **Password**: Auto-generated (save this!)
4. Click **Create**
5. Wait for database to be ready
6. Copy the **DATABASE_URL** from the database details page

**DATABASE_URL format**:
```
postgres://postgres:PASSWORD@INTERNAL_HOST:5432/vacancies_production
```

#### 3.2 Create Application in Coolify

1. Click **+ New Resource** → **Application**
2. Choose **Git Repository**
3. Configure Git source:
   - **Repository URL**: `https://github.com/yourusername/your-app.git`
   - **Branch**: `main`
   - For private repos: Add **GitHub Personal Access Token** in Settings
4. Choose **Docker Compose** as build pack
5. Set **Build Context**: `.` (root directory)

#### 3.3 Configure Environment Variables

In Coolify application settings, go to **Environment Variables** and add:

```bash
# Database
DATABASE_URL=postgres://postgres:PASSWORD@HOST:5432/vacancies_production

# Rails
RAILS_ENV=production
SECRET_KEY_BASE=<generate with: rails secret>
RAILS_LOG_LEVEL=info
RAILS_SERVE_STATIC_FILES=true
RAILS_LOG_TO_STDOUT=true

# Performance
RAILS_MAX_THREADS=5
WEB_CONCURRENCY=2
DATABASE_POOL_SIZE=30
JOB_CONCURRENCY=1

# Thruster (automatically set in Dockerfile, but can override)
THRUSTER_HTTP_PORT=80
THRUSTER_TARGET_PORT=3000

# Optional: If using private gems
BUNDLE_GITHUB__COM=x-access-token:YOUR_GITHUB_TOKEN
```

**Generate SECRET_KEY_BASE**:
```bash
rails secret
```

#### 3.4 Configure Custom Domain

1. In Coolify application, go to **Domains**
2. Click **Add Domain**
3. Enter your domain: `coolify.vacancies.at`
4. Coolify will show DNS records needed:
   ```
   Type: A
   Name: coolify.vacancies.at
   Value: YOUR_SERVER_IP
   ```
5. Add this DNS record in your domain provider (e.g., Cloudflare, Namecheap)
6. Wait for DNS propagation (usually 5-15 minutes)
7. Coolify will automatically generate Let's Encrypt SSL certificate

**Testing DNS propagation**:
```bash
dig coolify.vacancies.at
```

---

### Phase 4: Deploy

#### 4.1 Push to GitHub

```bash
git add .
git commit -m "Configure for Coolify deployment"
git push origin main
```

#### 4.2 Deploy in Coolify

1. Go to your application in Coolify
2. Click **Deploy**
3. Watch the build logs in real-time

**Expected build output**:
```
[+] Building 150.2s (24/24) FINISHED
 => [internal] load build definition
 => => transferring dockerfile
 => [internal] load .dockerignore
 => [base 1/4] FROM docker.io/library/ruby:3.4.2-slim
 => => resolve docker.io/library/ruby:3.4.2-slim
 => [build 7/11] COPY Gemfile Gemfile.lock ./
 => [build 8/11] RUN bundle install
 => [build 9/11] COPY . .
 => [build 10/11] RUN npm install
 => [build 11/11] RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
 => [stage-4 3/4] COPY --from=build /usr/local/bundle /usr/local/bundle
 => [stage-4 4/4] COPY --from=build /rails /rails
 => exporting to image
 => => exporting layers
 => => writing image
 => => naming to registry
```

**Expected startup logs**:
```
=========================================
PREPARING DATABASE (PRIMARY + SOLID CACHE/QUEUE/CABLE)
=========================================
Database prepared successfully
=========================================

Puma starting in cluster mode...
* Puma version: 6.5.0 (ruby 3.4.2-p0) ("Sky's Version")
* Min threads: 5
* Max threads: 5
* Environment: production
* Master PID: 15
* Workers: 2
* Restarts: 0
* Listening on tcp://0.0.0.0:3000
Use Ctrl-C to stop
```

#### 4.3 Verify Deployment

1. **Check application logs**:
   - Go to Coolify → Your App → **Logs**
   - Look for successful startup messages

2. **Test health endpoint**:
   ```bash
   curl -v https://coolify.vacancies.at/up
   ```

   Expected response:
   ```
   HTTP/2 200
   content-type: text/html; charset=utf-8

   <!DOCTYPE html><html><head>...</head></html>
   ```

3. **Test main application**:
   ```bash
   curl -v https://coolify.vacancies.at/
   ```

4. **Check from browser**:
   - Open `https://coolify.vacancies.at`
   - Should show your Rails app with valid SSL certificate

---

## Configuration Files

### Complete File Reference

Here are all the critical files and their final state:

#### `Dockerfile`
See [Phase 2.1](#21-create-optimized-dockerfile) above.

#### `docker-compose.yml`
See [Phase 2.2](#22-create-docker-composeyml-with-traefik-labels) above.

#### `bin/docker-entrypoint`
See [Phase 2.3](#23-create-docker-entrypoint-script) above.

#### `config/database.yml`
```yaml
default: &default
  adapter: postgresql
  encoding: unicode
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>

development:
  <<: *default
  database: vacanciesat_development

test:
  <<: *default
  database: vacanciesat_test

production:
  <<: *default
  url: <%= ENV["DATABASE_URL"] %>
  pool: <%= ENV.fetch("DATABASE_POOL_SIZE") { 30 } %>
  checkout_timeout: 5
  idle_timeout: <%= ENV.fetch("DATABASE_IDLE_TIMEOUT") { 300 } %>
```

#### `config/puma.rb`
```ruby
max_threads_count = ENV.fetch("RAILS_MAX_THREADS") { 5 }
min_threads_count = ENV.fetch("RAILS_MIN_THREADS") { max_threads_count }
threads min_threads_count, max_threads_count

port ENV.fetch("PORT", 3000)

# CRITICAL: Bind to 0.0.0.0 for Docker networking
bind "tcp://0.0.0.0:#{ENV.fetch('PORT', 3000)}"

environment ENV.fetch("RAILS_ENV") { "development" }
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

workers ENV.fetch("WEB_CONCURRENCY") { 2 }

preload_app!

plugin :tmp_restart

on_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord)
end

allow_puma_to_catch_up = true
```

#### `.dockerignore`
```
# Git
.git
.gitignore

# Logs
log/*
tmp/*
*.log

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode
.idea
*.swp
*.swo

# Environment
.env
.env.*

# Node modules
node_modules
npm-debug.log

# Test files
spec
test
coverage

# Documentation
README.md
*.md

# Development databases
*.sqlite3
```

---

## Logging Configuration

### Overview

By default, Rails logs to `log/production.log` which isn't visible in Coolify's log viewer. To see logs in Coolify without SSH-ing and tailing files, configure Rails to output logs to stdout/stderr.

### Why This Matters

**Problem**: Without proper configuration, you need to:
```bash
# SSH into server
ssh your-server
# Find container
docker ps
# Tail logs manually
docker exec CONTAINER_ID tail -f log/production.log
```

**Solution**: With proper stdout logging, all logs appear directly in Coolify's **Logs** tab in real-time.

### Required Configuration

This app includes all necessary logging configuration. Here's what's configured:

#### 1. SemanticLogger Configuration (If Using rails_semantic_logger Gem)

**IMPORTANT**: If your app uses the `rails_semantic_logger` gem, you need **special configuration** for Puma clustered mode.

**File**: `config/environments/production.rb`

```ruby
# SemanticLogger configuration for Docker/Coolify stdout logging
$stdout.sync = true
$stderr.sync = true

# Disable file-based logging in production (use stdout only)
config.rails_semantic_logger.add_file_appender = false

# Add stdout appender with color formatter for readable logs
config.semantic_logger.add_appender(
  io: $stdout,
  formatter: :color,  # Use :color for readable output, :json for machine parsing
  level: :info
)

# Enable detailed request logging (normally suppressed in production)
config.rails_semantic_logger.started = true      # "Started GET /path"
config.rails_semantic_logger.processing = true   # "Processing by Controller#action"
config.rails_semantic_logger.rendered = true     # "Rendering template"

# Keep request_id tags for log correlation
config.log_tags = [ :request_id ]
```

**File**: `config/puma.rb` (CRITICAL for SemanticLogger)

```ruby
# Reopen SemanticLogger appenders after forking workers
# Required because process forking drops the appender threads
on_worker_boot do
  SemanticLogger.reopen
end
```

**Why `SemanticLogger.reopen` is required**:

When Puma runs in clustered mode with `preload_app!`, it:
1. Preloads Rails app and starts SemanticLogger appender threads
2. Forks worker processes (e.g., `WEB_CONCURRENCY=2`)
3. **Forked workers lose the appender threads**
4. SemanticLogger has nowhere to send logs
5. You only see proxy logs (Thruster/Nginx), not Rails logs

Calling `SemanticLogger.reopen` in `on_worker_boot` restarts the appender threads in each forked worker, restoring logging.

**Reference**: [SemanticLogger Process Forking Guide](https://logger.rocketjob.io/forking.html)

#### 2. Standard Rails Logger (Without SemanticLogger)

**File**: `config/environments/production.rb`

```ruby
# Log to STDOUT with the current request id as a default log tag
config.log_tags = [ :request_id ]
config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

# Disable output buffering for real-time logs in Docker/Coolify
$stdout.sync = true
$stderr.sync = true
```

**What this does**:
- `config.logger = ...STDOUT`: Sends all Rails logs to stdout
- `$stdout.sync = true`: Disables buffering for immediate log visibility
- `$stderr.sync = true`: Errors appear immediately

#### 3. Environment Variable

**File**: `docker-compose.yml`

```yaml
services:
  web:
    environment:
      RAILS_LOG_TO_STDOUT: "true"
      # ... other env vars

  worker:
    environment:
      RAILS_LOG_TO_STDOUT: "true"
      # ... other env vars
```

**What this does**: Standard Rails convention to enable stdout logging.

#### 4. Log File Symlinks

**File**: `bin/docker-entrypoint`

```bash
# Symlink production log to stdout for Docker/Coolify log visibility
# This ensures file-based logs also appear in container logs
mkdir -p log
ln -sf /proc/1/fd/1 log/production.log
ln -sf /proc/1/fd/2 log/puma_error.log
```

**What this does**:
- Links `log/production.log` → Docker stdout (`/proc/1/fd/1`)
- Links `log/puma_error.log` → Docker stderr (`/proc/1/fd/2`)
- Any code that writes to log files now appears in Coolify's viewer

### What You'll See in Coolify Logs

With this configuration, Coolify's log viewer shows:

```
[web] Started GET "/vacancies" for 192.168.1.1 at 2025-11-20 10:15:23 +0000
[web] Processing by VacanciesController#index as HTML
[web]   Rendering layout layouts/application.html.erb
[web]   Rendering vacancies/index.html.erb within layouts/application
[web]   Vacancy Load (1.2ms)  SELECT "vacancies".* FROM "vacancies" WHERE "vacancies"."published" = $1 ORDER BY "vacancies"."created_at" DESC LIMIT $2  [["published", true], ["LIMIT", 20]]
[web]   Rendered vacancies/index.html.erb within layouts/application (Duration: 15.4ms | Allocations: 8234)
[web]   Rendered layout layouts/application.html.erb (Duration: 18.2ms | Allocations: 9876)
[web] Completed 200 OK in 25ms (Views: 16.5ms | ActiveRecord: 1.2ms | Allocations: 12345)

[worker] [SolidQueue] Processing AutoImportVacanciesJob
[worker] [SolidQueue] AutoImportVacanciesJob completed in 2.3s
```

### Log Levels

Control verbosity with `RAILS_LOG_LEVEL` environment variable:

```bash
# In Coolify environment variables
RAILS_LOG_LEVEL=info    # Default: requests, queries, errors
RAILS_LOG_LEVEL=debug   # All logs including SQL queries
RAILS_LOG_LEVEL=warn    # Only warnings and errors
RAILS_LOG_LEVEL=error   # Only errors
```

**Recommendation**: Use `info` in production, `debug` only for troubleshooting.

### Filtering Logs

#### Silence Health Checks

Already configured in `config/environments/production.rb`:

```ruby
config.silence_healthcheck_path = "/up"
```

This prevents `/up` health check requests from cluttering logs.

#### Filter Specific Logs in Coolify

In Coolify's log viewer, use the search/filter feature:
- Search for `ERROR` to see only errors
- Search for `VacanciesController` to see specific controller logs
- Search for `[worker]` to see only background job logs

### Testing Logging Configuration

After deployment, verify logs are working:

1. **Visit your application**: Navigate to any page
2. **Check Coolify logs**: Go to your app → **Logs** tab
3. **Should see**: Request logs appearing in real-time

```
Started GET "/" for 1.2.3.4 at 2025-11-20 10:20:00 +0000
Processing by PagesController#home as HTML
Completed 200 OK in 15ms (Views: 12.0ms | ActiveRecord: 1.5ms)
```

4. **Trigger an error**: Visit a non-existent page (404)
5. **Should see**: Error logged immediately

```
Started GET "/nonexistent" for 1.2.3.4 at 2025-11-20 10:21:00 +0000
Processing by ApplicationController#not_found as HTML
Completed 404 Not Found in 2ms
```

### Troubleshooting Logs

#### CRITICAL: SemanticLogger Logs Not Appearing (Only Proxy Logs Showing)

**Symptoms**: You only see Thruster/Nginx proxy logs (JSON format), but no Rails request logs:
```json
{"time":"...","level":"INFO","msg":"Request","path":"/dashboard","status":200,...}
```

Missing:
```
Started GET "/dashboard" for 192.168.1.1
Processing by DashboardController#index
Completed 200 OK in 25ms
```

**Root Cause**: If using `rails_semantic_logger` gem with Puma in clustered mode, worker forking drops SemanticLogger's appender threads.

**Solution**: Add to `config/puma.rb`:
```ruby
on_worker_boot do
  SemanticLogger.reopen
end
```

**Verification**: After deploying, check for these startup messages in logs:
```
[28] - Worker 0 (PID: 42) booted in 0.0s, phase: 0
[28] - Worker 1 (PID: 50) booted in 0.0s, phase: 0
```

If you see worker boot messages but still no Rails logs, SemanticLogger needs `.reopen` call.

**Why this happens**:
1. App preloads with `preload_app!` → SemanticLogger starts appender thread
2. Puma forks workers → Forked processes lose appender thread
3. Logs have nowhere to go → Only proxy logs appear

**Reference**: This is a known SemanticLogger limitation documented in their [Process Forking Guide](https://logger.rocketjob.io/forking.html).

#### Logs Not Appearing (General)

**Check 1**: Verify environment variable is set
```bash
# In Coolify, go to Environment Variables
# Ensure RAILS_LOG_TO_STDOUT=true is present
```

**Check 2**: Verify container is running
```bash
# In Coolify logs, look for startup messages
PREPARING DATABASE (PRIMARY + SOLID CACHE/QUEUE/CABLE)
✓ Database prepared successfully
Puma starting in cluster mode...
* Listening on tcp://0.0.0.0:3000
```

**Check 3**: Check for buffering issues
If logs appear in batches (delayed), verify `$stdout.sync = true` is in `config/environments/production.rb`.

#### Too Many Logs

**Solution 1**: Increase log level
```bash
RAILS_LOG_LEVEL=warn  # Only warnings and errors
```

**Solution 2**: Add custom log filtering
```ruby
# config/environments/production.rb
config.log_tags = [ :request_id ]

# Filter out specific paths
config.middleware.insert_before Rails::Rack::Logger, YourApp::Middleware::LogFilter
```

#### Worker Logs Not Showing

Ensure worker service also has `RAILS_LOG_TO_STDOUT: "true"` in `docker-compose.yml` (already configured in this app).

### Best Practices

1. **Use structured logging** for easier parsing:
   ```ruby
   Rails.logger.info({ event: "vacancy_created", vacancy_id: @vacancy.id, user_id: current_user.id }.to_json)
   ```

2. **Include request IDs** for tracing (already configured):
   ```ruby
   config.log_tags = [ :request_id ]
   ```

3. **Log important business events**:
   ```ruby
   Rails.logger.info "User #{user.email} created vacancy: #{vacancy.title}"
   ```

4. **Don't log sensitive data**:
   ```ruby
   # BAD
   Rails.logger.info "Password: #{params[:password]}"

   # GOOD
   Rails.logger.info "User authentication attempt for: #{params[:email]}"
   ```

5. **Use appropriate log levels**:
   - `debug`: Detailed diagnostic info
   - `info`: General informational messages
   - `warn`: Warning messages for potentially harmful situations
   - `error`: Error messages for failures
   - `fatal`: Critical errors causing shutdown

### Advanced: External Log Aggregation

For production apps with high traffic, consider external log aggregation:

- **Sentry**: Error tracking and monitoring
- **Papertrail**: Centralized log management
- **Logtail**: Real-time log aggregation
- **Datadog**: Full observability platform

These integrate via:
1. Add gem to Gemfile
2. Configure in `config/environments/production.rb`
3. Logs automatically forwarded to external service

---

## Post-Deployment Verification

After deploying, verify all systems are working:

### 1. Web Access
```bash
# Test SSL and basic access
curl -I https://vacancies.at

# Should return:
# HTTP/2 200
# SSL certificate valid
```

### 2. Mission Control Dashboard
1. Visit https://vacancies.at/jobs
2. Login with `MISSION_CONTROL_PASSWORD`
3. Verify:
   - ✅ Solid Queue supervisor running
   - ✅ No failed jobs in queue
   - ✅ Workers processing jobs

### 3. Background Jobs
```ruby
# Enqueue a test job via Rails console
docker exec <web-container> rails runner "TestJob.perform_later"

# Check Mission Control for job processing
# Verify job completes successfully
```

### 4. File Uploads
1. Upload a file (company logo, document)
2. Verify stored in Cloudflare R2:
   - Check R2 dashboard for new file
   - Verify file accessible via URL
3. Test direct upload progress bar (for large files)

### 5. PDF Generation (Chrome/Puppeteer)
```bash
# Verify Chrome installed
docker exec <web-container> which google-chrome-stable
docker exec <web-container> google-chrome-stable --version

# Test PDF generation feature in app
# Check logs for any Chrome errors
```

### 6. Email Delivery
1. Trigger a transactional email (e.g., password reset)
2. Check Postmark dashboard:
   - ✅ Email sent successfully
   - ✅ No bounces or errors
3. Verify email received

### 7. Payments (if applicable)
1. Test Stripe checkout flow
2. Verify webhook receiving events:
   - Check logs for webhook POST requests
   - Verify webhook signature validation passes
3. Confirm credits/wallet updates correctly

### 8. Database Operations
```bash
# Check database migrations
docker exec <web-container> rails db:migrate:status

# Verify Solid libraries tables exist
docker exec <web-container> rails runner "
puts 'Cache: ' + Solid::Cache::Entry.count.to_s
puts 'Queue: ' + SolidQueue::Job.count.to_s
puts 'Cable: ' + SolidCable::Message.count.to_s
"
```

### 9. Logs Visibility
```bash
# Check logs appear in Coolify
# Should see Rails requests, Puma workers, background jobs

# Test log generation
docker exec <web-container> rails runner "Rails.logger.info 'Test log entry'"

# Verify appears in Coolify logs within 5 seconds
```

### 10. Performance Check
```bash
# Check page load time
curl -w "%{time_total}\n" -o /dev/null -s https://vacancies.at

# Should be < 2 seconds for cached pages
```

---

## Common Issues & Solutions

### Issue 1: "No database connection defined for 'cache' shard"

**Symptoms**:
```
ActiveRecord::ConnectionNotEstablished: No database connection defined for 'cache' shard
```

**Root Cause**: Rails 8 defaults to multi-database configuration for Solid libraries, but tables don't exist in separate databases.

**Solution**:
1. Remove `database: cache` from `config/cache.yml`
2. Remove `connects_to` from `config/cable.yml` and `config/environments/production.rb`
3. Create migrations for Solid tables in primary database (see Phase 1.2)
4. Run `rails db:migrate`

**Prevention**: Always use single-database approach unless you genuinely need separate databases for performance isolation.

---

### Issue 2: "no available server" when accessing domain

**Symptoms**:
- Browser shows "no available server" error
- Application is running inside container
- `curl http://localhost:80` works from inside container

**Root Cause**: Traefik cannot route to your application because either:
1. `PORT` environment variable is wrong
2. Traefik labels are missing or incorrect

**Solution**:

**Step 1**: Verify PORT configuration
```yaml
# In docker-compose.yml
environment:
  PORT: "80"  # MUST be 80, not 3000
```

**Step 2**: Add Traefik labels
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.services.YOUR-APP-NAME.loadbalancer.server.port=80"
  - "traefik.http.routers.YOUR-APP-NAME.rule=Host(`your-domain.com`)"
  - "traefik.http.routers.YOUR-APP-NAME.entrypoints=websecure"
  - "traefik.http.routers.YOUR-APP-NAME.tls=true"
```

**Step 3**: Verify container is on Coolify network
```yaml
networks:
  - coolify

networks:
  coolify:
    external: true
    name: coolify
```

**Debugging commands**:
```bash
# Check container networking
docker ps
# Should show: 80/tcp, not 0.0.0.0:80->80/tcp

# Check if container is on Coolify network
docker inspect YOUR_CONTAINER_ID | grep coolify

# Test from inside container
docker exec YOUR_CONTAINER_ID curl -v http://localhost:80/up
```

---

### Issue 3: PG::DuplicateTable - Tables already exist

**Symptoms**:
```
PG::DuplicateTable: ERROR: relation "solid_queue_jobs" already exists
```

**Root Cause**: Migrations try to create tables that Rails 8 already created during initial setup.

**Solution**: Add idempotency checks to all migrations:
```ruby
class CreateSolidQueue < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_queue_jobs)

    # ... rest of migration
  end
end
```

**Why this works**: The migration will skip table creation if they already exist, allowing `db:prepare` to run successfully.

---

### Issue 4: RAILS_MASTER_KEY errors (when using .env only)

**Symptoms**:
```
Missing encryption key to decrypt file with. Ask your team for your master key and write it to config/master.key
```

**Root Cause**: App has `config/credentials.yml.enc` but you're using `.env` files for secrets.

**Solution**:
```bash
# Delete encrypted credentials
rm config/credentials.yml.enc
rm config/master.key

# Update config/application.rb
config.credentials.content_path = nil
```

**Alternative**: If you DO want to use Rails credentials:
```bash
# Set RAILS_MASTER_KEY in Coolify environment variables
RAILS_MASTER_KEY=your_master_key_here
```

---

### Issue 5: Private gem authentication failures

**Symptoms**:
```
Fetching https://github.com/yourorg/private-gem.git
fatal: could not read Username for 'https://github.com': No such device or address
```

**Root Cause**: Bundler cannot authenticate to private GitHub repositories.

**Solutions**:

**Option 1: Configure Git to use HTTPS (recommended for Docker)**
```dockerfile
# In Dockerfile
RUN git config --global url."https://github.com/".insteadOf git@github.com: && \
    bundle install --with BUNDLE_GITHUB__COM="x-access-token:${GITHUB_TOKEN}"
```

**Option 2: Use Docker secrets**
```dockerfile
RUN --mount=type=secret,id=github_token \
    BUNDLE_GITHUB__COM="x-access-token:$(cat /run/secrets/github_token)" bundle install
```

Then in Coolify, add environment variable:
```
BUNDLE_GITHUB__COM=x-access-token:YOUR_GITHUB_TOKEN
```

**Generate GitHub token**:
1. GitHub → Settings → Developer settings → Personal access tokens
2. Generate new token (classic)
3. Select scopes: `repo` (for private repositories)
4. Copy token and add to Coolify environment variables

---

### Issue 6: Asset precompilation fails

**Symptoms**:
```
ArgumentError: Missing `secret_key_base` for 'production' environment
```

**Root Cause**: Rails requires SECRET_KEY_BASE even during asset compilation.

**Solution**: Use dummy key during build:
```dockerfile
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile
```

**Important**: This is safe because:
- Assets don't need real secrets
- Real SECRET_KEY_BASE is provided at runtime via environment variables

---

### Issue 7: Slow Docker builds

**Symptoms**:
- Builds take 10+ minutes
- Re-running builds doesn't use cache
- Downloading same packages every time

**Solution**: Enable BuildKit and use cache mounts:

```dockerfile
# syntax=docker/dockerfile:1

# Cache apt packages
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y PACKAGES

# Cache bundler gems
RUN --mount=type=cache,target=/usr/local/bundle/cache,sharing=locked \
    bundle install

# Cache npm packages
RUN --mount=type=cache,target=/rails/node_modules,sharing=locked \
    npm install
```

**Enable BuildKit in Coolify**:
BuildKit is enabled by default in recent Docker versions. If you need to force it:
```bash
export DOCKER_BUILDKIT=1
```

**Performance improvement**: Builds go from 10 minutes → 2-3 minutes on subsequent builds.

---

### Issue 8: SemanticLogger logs not appearing (only proxy logs showing)

**Symptoms**:
- Coolify logs only show Thruster/Nginx proxy logs in JSON format
- No detailed Rails request logs (Started GET, Processing by, Completed)
- App is working but logs are missing

Example of what you see (proxy logs only):
```json
{"time":"2025-11-20...","level":"INFO","msg":"Request","path":"/dashboard","status":200,...}
```

**Root Cause**: When using `rails_semantic_logger` gem with Puma in clustered mode (`workers > 1`), process forking drops SemanticLogger's appender threads.

**The Flow**:
1. Rails app preloads with `preload_app!`
2. SemanticLogger starts appender threads for stdout logging
3. Puma forks worker processes (e.g., `WEB_CONCURRENCY=2`)
4. **Forked workers lose the appender threads**
5. SemanticLogger has nowhere to send logs
6. Only proxy logs appear (they use a different mechanism)

**Solution**: Add to `config/puma.rb` after `preload_app!`:

```ruby
preload_app!

# Reopen SemanticLogger appenders after forking workers
on_worker_boot do
  SemanticLogger.reopen
end
```

**Complete SemanticLogger Configuration**:

In `config/environments/production.rb`:
```ruby
# SemanticLogger configuration for Docker/Coolify stdout logging
$stdout.sync = true
$stderr.sync = true

# Disable file-based logging
config.rails_semantic_logger.add_file_appender = false

# Add stdout appender
config.semantic_logger.add_appender(
  io: $stdout,
  formatter: :color,
  level: :info
)

# Enable detailed request logging
config.rails_semantic_logger.started = true
config.rails_semantic_logger.processing = true
config.rails_semantic_logger.rendered = true
```

**Verification**:
After deploying, you should see detailed logs:
```
Started GET "/dashboard" for 192.168.1.1 at 2025-11-20 10:00:00 +0000
Processing by DashboardController#index as HTML
  Company Load (1.2ms)  SELECT "companies".*...
Completed 200 OK in 25ms (Views: 16ms | ActiveRecord: 1ms)
```

**Reference**: [SemanticLogger Process Forking Documentation](https://logger.rocketjob.io/forking.html)

**Why this is often missed**: This is a specific SemanticLogger requirement for forking web servers. The gem works fine in development (single process) but silently fails in production with worker forking unless `.reopen` is called.

---

## Rails 8 Specific: Solid Libraries

### What are Solid Libraries?

Rails 8 introduces database-backed alternatives to Redis/Memcached:
- **Solid Cache**: Database-backed caching (replaces Redis/Memcached)
- **Solid Queue**: Database-backed job processing (replaces Sidekiq/Resque)
- **Solid Cable**: Database-backed WebSockets (replaces ActionCable with Redis)

### Benefits
- **Simpler infrastructure**: No Redis server needed
- **Lower costs**: One database instead of multiple services
- **Better persistence**: Jobs/cache survive restarts
- **Easy backups**: Everything in PostgreSQL

### Trade-offs
- **Performance**: Slightly slower than Redis for high-throughput scenarios
- **Database load**: Adds queries to your primary database
- **Not for extreme scale**: Redis is better for 1M+ operations/second

### Single vs Multi-Database Approach

#### Single Database (Recommended for Small-Medium Apps)
**Pros**:
- Simpler configuration
- Easier backups (one database)
- Lower infrastructure costs
- Faster deployments

**Cons**:
- Shared connection pool
- Job processing queries compete with app queries

**When to use**: Most applications, especially if you're:
- Getting started with Rails 8
- Have < 100 req/second
- Want simplicity over micro-optimization

#### Multi-Database (For High-Scale Apps)
**Pros**:
- Isolated performance
- Dedicated connection pools
- Can scale databases independently

**Cons**:
- More complex configuration
- Multiple database instances
- Higher infrastructure costs
- Harder to manage

**When to use**: Large-scale applications where:
- You have 1000+ req/second
- Job processing is heavy (millions of jobs/day)
- You need guaranteed app performance isolation

### Migration Patterns

#### Pattern 1: Idempotent Migrations (Recommended)
```ruby
class CreateSolidCache < ActiveRecord::Migration[8.0]
  def change
    return if table_exists?(:solid_cache_entries)

    # Create tables...
  end
end
```

**Why**: Allows running migrations multiple times without errors.

#### Pattern 2: Use db:prepare (Not db:migrate)
```bash
# In bin/docker-entrypoint
./bin/rails db:prepare
```

**Why**: `db:prepare` creates database if needed, loads schema, runs pending migrations. Safe for fresh deployments and updates.

---

## Performance Optimization

### Docker Build Optimization

#### 1. Use BuildKit Cache Mounts
```dockerfile
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && apt-get install -y packages
```

**Impact**: 5-10x faster builds on cache hits.

#### 2. Multi-Stage Builds
```dockerfile
FROM ruby:3.4.2-slim AS build
# Build dependencies, compile assets

FROM ruby:3.4.2-slim AS final
COPY --from=build /rails /rails
```

**Impact**: 50% smaller final image.

#### 3. Layer Ordering
```dockerfile
# Change rarely → top
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Change frequently → bottom
COPY . .
```

**Impact**: Better cache utilization, faster rebuilds.

### Rails Application Optimization

#### 1. Connection Pool Sizing
```yaml
# config/database.yml
production:
  pool: <%= ENV.fetch("DATABASE_POOL_SIZE") { 30 } %>
```

**Formula**: `pool = (WEB_CONCURRENCY * RAILS_MAX_THREADS) + margin`

**Example**:
- WEB_CONCURRENCY=2 (Puma workers)
- RAILS_MAX_THREADS=5
- Pool = (2 * 5) + 20 margin = 30

#### 2. Puma Worker Configuration
```ruby
# config/puma.rb
workers ENV.fetch("WEB_CONCURRENCY") { 2 }
```

**Sizing**:
- **1 CPU**: 2 workers
- **2 CPUs**: 3-4 workers
- **4 CPUs**: 5-6 workers

**Memory**: Each worker uses ~150-300MB

#### 3. Enable Bootsnap
```dockerfile
RUN bundle exec bootsnap precompile app/ lib/
```

**Impact**: 30-50% faster boot times.

#### 4. Static Asset Serving
```ruby
# config/environments/production.rb
config.public_file_server.enabled = ENV["RAILS_SERVE_STATIC_FILES"].present?
```

**When to enable**: If not using CDN or separate asset server.

**Impact**: Thruster handles static files efficiently without hitting Rails.

### Database Optimization

#### 1. Connection Pooling
```yaml
production:
  checkout_timeout: 5
  idle_timeout: 300
```

**Prevents**: Connection exhaustion under load.

#### 2. Prepared Statements
Automatically enabled in PostgreSQL adapter.

**Impact**: 10-20% faster query execution.

#### 3. Indexes for Solid Tables
All Solid migrations include proper indexes:
```ruby
t.index :key_hash, unique: true  # Solid Cache
t.index [:queue_name, :finished_at]  # Solid Queue
t.index :created_at  # Solid Cable
```

**Impact**: Fast lookups even with millions of records.

---

## Scaling

### Scaling Recommendations by Traffic Level

| Traffic Level | Daily Users | RAM | CPU | Disk | WEB_CONCURRENCY | Workers | DB Pool |
|--------------|-------------|-----|-----|------|-----------------|---------|---------|
| **Low** | < 1,000 | 2GB | 2 cores | 40GB | 2 | 1 | 10 |
| **Medium** | 1,000-10,000 | 4GB | 2-4 cores | 60GB | 3-4 | 2 | 20 |
| **High** | 10,000-50,000 | 8GB | 4-6 cores | 100GB | 5-6 | 3 | 30 |
| **Very High** | 50,000+ | 16GB+ | 8+ cores | 200GB+ | 8+ | 4+ | 50+ |

### Vertical Scaling (Single Server)

**When to scale up:**
- CPU usage consistently > 70%
- Memory usage consistently > 80%
- Disk I/O wait times increasing
- Response times degrading

**How to scale:**
1. In Coolify, go to Application → Resources
2. Increase RAM and CPU allocation
3. Update environment variables:
   ```bash
   WEB_CONCURRENCY=4  # Increase Puma workers
   RAILS_MAX_THREADS=5  # Increase threads per worker
   DATABASE_POOL_SIZE=30  # Increase DB connections
   ```
4. Redeploy application

### Horizontal Scaling (Multiple Servers)

**When to consider:**
- Single server maxed out (16GB+ RAM, 8+ cores)
- Need better availability/redundancy
- Traffic spikes require elastic scaling

**Architecture for horizontal scaling:**
```
┌─────────────┐
│ Load        │
│ Balancer    │
└──────┬──────┘
       │
   ┌───┴────┬────────┬────────┐
   ▼        ▼        ▼        ▼
┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐
│Web  │  │Web  │  │Web  │  │Web  │
│Node │  │Node │  │Node │  │Node │
└──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘
   │        │        │        │
   └────────┴────────┴────────┘
            │
       ┌────┴────┐
       │         │
    ┌──▼──┐  ┌──▼──┐
    │ DB  │  │Queue│
    │ Primary│  │Worker│
    └─────┘  └─────┘
```

**Considerations:**
- Shared PostgreSQL database (or read replicas)
- Centralized Solid Queue workers (or distributed with leader election)
- Session store in database (not cookies/filesystem)
- File storage in R2 (already centralized)

### Database Scaling

**Read replicas:**
```ruby
# config/database.yml
production:
  primary:
    <<: *default
    database: vacanciesat_production

  primary_replica:
    <<: *default
    database: vacanciesat_production
    host: replica-host
    replica: true
```

**Connection pooling:**
```bash
# Adjust based on: (WEB_CONCURRENCY * RAILS_MAX_THREADS) + 10
DATABASE_POOL_SIZE=30
```

### Monitoring Metrics

Track these metrics to inform scaling decisions:
- **Response Time**: p50, p95, p99 latencies
- **Throughput**: Requests per second
- **Error Rate**: 5xx errors percentage
- **CPU Usage**: Per container
- **Memory Usage**: Per container
- **Database Connections**: Active vs. available
- **Queue Length**: Pending jobs in Solid Queue
- **Queue Processing Time**: Job latency

---

## Backup Strategy

### Database Backups

**Automated Coolify backups:**
1. Go to Database → Backups
2. Enable automated backups:
   - **Frequency**: Daily at 3:00 AM
   - **Retention**: 7 days
   - **Location**: Coolify backup storage

**Manual backup:**
```bash
# Via Coolify CLI
coolify db:backup vacancies-postgres

# Or via Docker
docker exec vacancies-postgres pg_dump -U postgres vacanciesat_production > backup.sql
```

**Database export feature:**
- Use the built-in database export/import feature
- Navigate to `/admin/data_transfers`
- Click "Download Database Export"
- Saves complete database as JSON (portable across environments)
- See [DATABASE_EXPORT_IMPORT_GUIDE.md](./DATABASE_EXPORT_IMPORT_GUIDE.md) for details

### File Storage Backups

**Cloudflare R2:**
- Built-in redundancy (11 9's durability)
- Optional versioning enabled
- No additional backup needed
- Geographic redundancy across multiple regions

**If using local disk storage:**
```bash
# Backup storage directory
tar -czf storage-backup.tar.gz storage/

# Or use rsync to remote location
rsync -avz storage/ backup-server:/backups/vacanciesat/storage/
```

### Configuration Backups

**Save these in password manager:**
- All environment variables
- `docker-compose.yml`
- Coolify application settings
- Third-party API keys
- This documentation

**Git repository:**
- Code and configuration files version-controlled
- Tagged releases for each deployment
- Ability to roll back to any previous version

### Recovery Testing

**Test restoration quarterly:**
```bash
# 1. Create test environment
# 2. Restore database from backup
# 3. Configure environment variables
# 4. Deploy application
# 5. Verify all functionality works
# 6. Document any issues
```

### Disaster Recovery Plan

**RTO (Recovery Time Objective)**: < 4 hours
**RPO (Recovery Point Objective)**: < 24 hours

**Recovery steps:**
1. Provision new Coolify server (or use existing backup server)
2. Create PostgreSQL database
3. Restore database from most recent backup
4. Configure environment variables from password manager
5. Deploy application from Git repository
6. Update DNS to point to new server
7. Verify all systems operational
8. Monitor for issues

---

## Security Considerations

### 1. Run as Non-Root User
```dockerfile
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash
USER 1000:1000
```

**Why**: Limits damage if container is compromised.

### 2. Don't Commit Secrets
```bash
# .gitignore
.env
.env.*
config/master.key
config/credentials/*.key
```

**Alternative**: Use Coolify environment variables.

### 3. Use Build Secrets (Not ENV)
```dockerfile
RUN --mount=type=secret,id=github_token \
    BUNDLE_GITHUB__COM="x-access-token:$(cat /run/secrets/github_token)" bundle install
```

**Why**: Secrets don't appear in Docker image layers.

### 4. Enable Force SSL
```ruby
# config/environments/production.rb
config.force_ssl = true
```

**Why**: Ensures all traffic uses HTTPS.

### 5. Set Security Headers
Rails 8 includes secure defaults, but verify:
```ruby
config.action_dispatch.default_headers = {
  'X-Frame-Options' => 'SAMEORIGIN',
  'X-Content-Type-Options' => 'nosniff',
  'X-XSS-Protection' => '0',
  'Referrer-Policy' => 'strict-origin-when-cross-origin'
}
```

### 6. Database SSL (Production)
```yaml
# config/database.yml
production:
  sslmode: require
```

**When**: If database is external or on different server.

---

## Troubleshooting

### Debugging Checklist

#### 1. Container Won't Start
```bash
# View logs
docker logs CONTAINER_ID

# Common issues:
# - Database connection failed → Check DATABASE_URL
# - Missing SECRET_KEY_BASE → Check environment variables
# - Migration failed → Check db:prepare output
```

#### 2. Application Unreachable
```bash
# Test from inside container
docker exec CONTAINER_ID curl -v http://localhost:80/up

# Test from server
curl -v http://localhost:80/up

# Check Traefik routing
docker logs TRAEFIK_CONTAINER_ID | grep your-domain

# Verify Traefik labels
docker inspect CONTAINER_ID | grep traefik
```

#### 3. Slow Performance
```bash
# Check resource usage
docker stats CONTAINER_ID

# View database queries
# In rails console:
ActiveRecord::Base.logger = Logger.new(STDOUT)

# Check Puma stats
curl http://localhost:3000/stats  # If enabled
```

#### 4. Jobs Not Processing
```bash
# Check worker container
docker logs WORKER_CONTAINER_ID

# Verify Solid Queue tables exist
docker exec WEB_CONTAINER_ID rails runner "puts SolidQueue::Job.count"

# Check for failed jobs
docker exec WEB_CONTAINER_ID rails runner "puts SolidQueue::FailedExecution.count"
```

#### 5. Assets Not Loading
```bash
# Verify assets compiled
docker exec CONTAINER_ID ls -la public/assets

# Check asset host configuration
docker exec CONTAINER_ID rails runner "puts Rails.application.config.asset_host"

# Verify Thruster serving static files
curl -v https://your-domain.com/assets/application-DIGEST.css
```

### Common Error Messages

#### "Could not find table 'solid_queue_jobs'"
**Fix**: Run migrations
```bash
docker exec CONTAINER_ID rails db:migrate
```

#### "Puma caught this error: Address already in use"
**Fix**: PORT conflict, check PORT environment variable
```bash
docker exec CONTAINER_ID env | grep PORT
```

#### "ActiveRecord::ConnectionNotEstablished"
**Fix**: Check DATABASE_URL
```bash
docker exec CONTAINER_ID env | grep DATABASE_URL
```

#### "Rack::Timeout::RequestTimeoutException"
**Fix**: Increase timeout or optimize slow code
```ruby
# config/environments/production.rb
Rack::Timeout.timeout = 30  # seconds
```

### Application-Specific Troubleshooting

#### Chrome/Puppeteer Not Found (PDF Generation)

**Symptoms:**
- PDF generation fails
- Error: "Could not find Chrome binary"
- Grover gem errors

**Diagnosis:**
```bash
# Check if Chrome is installed
docker exec <web-container> which google-chrome-stable

# Check Chrome version
docker exec <web-container> google-chrome-stable --version

# Test Chrome launch
docker exec <web-container> google-chrome-stable --no-sandbox --headless --dump-dom https://www.google.com
```

**Fix:**
1. Verify Dockerfile includes Chrome installation:
   ```dockerfile
   # Install Chrome for PDF generation
   RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
       && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
       && apt-get update \
       && apt-get install -y google-chrome-stable
   ```

2. Clear Docker build cache and rebuild:
   ```bash
   # In Coolify, trigger rebuild with cache cleared
   # Or manually: docker build --no-cache .
   ```

3. Verify Grover configuration uses `--no-sandbox` flag:
   ```ruby
   # config/initializers/grover.rb
   Grover.configuration do |config|
     config.options = {
       launch_args: ['--no-sandbox', '--disable-setuid-sandbox']
     }
   end
   ```

#### Worker Not Processing Jobs

**Symptoms:**
- Jobs stuck in "pending" state
- Mission Control shows no active workers
- Queue length growing

**Diagnosis:**
```bash
# Check worker container logs
docker logs <worker-container>

# Check if worker process is running
docker exec <worker-container> ps aux | grep solid_queue

# Check database connection from worker
docker exec <worker-container> rails runner "puts ActiveRecord::Base.connection.active?"
```

**Fix:**
1. Verify `docker-compose.yml` has worker service:
   ```yaml
   worker:
     <<: *app
     command: bundle exec rake solid_queue:start
     environment:
       - DATABASE_URL=${DATABASE_URL}
       - QUEUE_DATABASE_POOL_SIZE=10
   ```

2. Check Solid Queue tables exist:
   ```bash
   docker exec <web-container> rails runner "puts SolidQueue::Job.table_exists?"
   ```

3. Restart worker container:
   ```bash
   docker restart <worker-container>
   ```

#### Direct Upload "Status: 0" Error

**Symptoms:**
- File upload shows "Status: 0" error
- Upload progress stops immediately
- Browser console shows CORS error

**Diagnosis:**
```bash
# Test CORS from command line
curl -I -X OPTIONS \
  -H "Origin: https://vacancies.at" \
  -H "Access-Control-Request-Method: PUT" \
  https://your-bucket.r2.cloudflarestorage.com

# Check browser console for CORS errors
# Look for: "Access-Control-Allow-Origin" errors
```

**Fix:**
Configure CORS on Cloudflare R2 bucket (see [DATABASE_EXPORT_IMPORT_GUIDE.md](./DATABASE_EXPORT_IMPORT_GUIDE.md#cloudflare-r2-configuration)):
```json
{
  "AllowedOrigins": ["https://vacancies.at"],
  "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
  "AllowedHeaders": ["*"],
  "ExposeHeaders": ["ETag"],
  "MaxAgeSeconds": 3600
}
```

#### Stripe Webhook Not Receiving Events

**Symptoms:**
- Payments complete but credits not added
- No webhook logs in Rails logs
- Stripe dashboard shows webhook failures

**Diagnosis:**
```bash
# Check webhook endpoint is accessible
curl -I https://vacancies.at/webhooks/payments/stripe

# Check Rails logs for webhook POST requests
docker logs <web-container> | grep "/webhooks/payments/stripe"

# Check Stripe dashboard → Webhooks → Recent deliveries
```

**Fix:**
1. Verify webhook URL matches exactly in Stripe dashboard
2. Check `STRIPE_WEBHOOK_SECRET` environment variable is set
3. Verify webhook controller exists and handles signature validation:
   ```ruby
   # app/controllers/webhooks/payments/stripe_controller.rb
   payload = request.body.read
   sig_header = request.env['HTTP_STRIPE_SIGNATURE']
   event = Stripe::Webhook.construct_event(
     payload, sig_header, ENV['STRIPE_WEBHOOK_SECRET']
   )
   ```

4. Test webhook with Stripe CLI:
   ```bash
   stripe listen --forward-to https://vacancies.at/webhooks/payments/stripe
   stripe trigger checkout.session.completed
   ```

---

## Deployment Checklist

Use this checklist for deploying new Rails 8 apps to Coolify:

### Pre-Deployment

- [ ] Rails 8.x installed
- [ ] PostgreSQL configured (not SQLite)
- [ ] Git repository created (GitHub)
- [ ] Private gems use HTTPS authentication
- [ ] `.env` files used for secrets (or Rails credentials configured)
- [ ] Asset pipeline configured (Propshaft/Sprockets)

### Configuration Files

- [ ] `Dockerfile` created with multi-stage build
- [ ] `docker-compose.yml` created with Traefik labels
- [ ] `bin/docker-entrypoint` created and executable (`chmod +x`)
- [ ] `.dockerignore` created
- [ ] `config/database.yml` configured for single database
- [ ] `config/cache.yml` without `database:` key
- [ ] `config/cable.yml` without `connects_to`
- [ ] `config/queue.yml` without `connects_to`
- [ ] `config/environments/production.rb` without `connects_to`
- [ ] `config/environments/production.rb` has `$stdout.sync = true` for unbuffered logs
- [ ] `config/puma.rb` binds to `0.0.0.0`
- [ ] `config/puma.rb` has `on_worker_boot { SemanticLogger.reopen }` (if using rails_semantic_logger)
- [ ] `bin/docker-entrypoint` symlinks log files to stdout
- [ ] Solid migrations created with idempotency checks
- [ ] `Procfile` created (optional)

### Docker Configuration

- [ ] `THRUSTER_HTTP_PORT=80` in Dockerfile
- [ ] `THRUSTER_TARGET_PORT=3000` in Dockerfile
- [ ] `PORT: "80"` in docker-compose.yml
- [ ] `EXPOSE 80` in Dockerfile
- [ ] Traefik labels include `traefik.enable=true`
- [ ] Traefik labels specify correct port: `loadbalancer.server.port=80`
- [ ] Traefik labels specify domain: `rule=Host(...)`
- [ ] Network configured: `networks: coolify`
- [ ] BuildKit syntax enabled: `# syntax=docker/dockerfile:1`

### Coolify Setup

- [ ] PostgreSQL database created
- [ ] DATABASE_URL copied
- [ ] Application created from Git repository
- [ ] Build pack set to Docker Compose
- [ ] Environment variables configured:
  - [ ] `DATABASE_URL`
  - [ ] `SECRET_KEY_BASE` (generated with `rails secret`)
  - [ ] `RAILS_ENV=production`
  - [ ] `RAILS_SERVE_STATIC_FILES=true`
  - [ ] `RAILS_LOG_TO_STDOUT=true` (for Coolify log visibility)
  - [ ] `PORT=80`
  - [ ] `WEB_CONCURRENCY`
  - [ ] `RAILS_MAX_THREADS`
  - [ ] `DATABASE_POOL_SIZE`
  - [ ] `BUNDLE_GITHUB__COM` (if using private gems)
- [ ] Custom domain configured
- [ ] DNS records added (A record pointing to server IP)
- [ ] SSL certificate auto-generated (Let's Encrypt)

### Deployment

- [ ] Code committed to Git
- [ ] Code pushed to GitHub
- [ ] Deploy triggered in Coolify
- [ ] Build completes successfully
- [ ] Database migrations run (check logs)
- [ ] Container starts (check logs)
- [ ] Health endpoint responds: `/up`
- [ ] Application accessible via domain
- [ ] SSL certificate valid (HTTPS works)
- [ ] HTTP redirects to HTTPS
- [ ] Background jobs processing (check worker logs)

### Post-Deployment

- [ ] Logs appear in Coolify's Logs tab (verify stdout logging works)
- [ ] Monitor logs for errors
- [ ] Test critical user flows
- [ ] Verify database connections are stable
- [ ] Check job processing works (check worker logs)
- [ ] Monitor resource usage (CPU, memory)
- [ ] Set up backups (database)
- [ ] Configure monitoring/alerting (optional)

---

## Conclusion

You now have a complete guide for deploying Rails 8 applications to Coolify with:

✅ **Optimized Docker configuration** with BuildKit cache mounts
✅ **Single-database Solid libraries** (Cache, Queue, Cable)
✅ **Traefik integration** for automatic SSL and routing
✅ **Production-ready Puma** cluster mode
✅ **Real-time logging** visible in Coolify's UI
✅ **Comprehensive troubleshooting** for common issues

### Key Takeaways

1. **PORT must be 80** for Traefik routing
2. **Traefik labels are required** for service discovery
3. **Single database is simpler** than multi-database for Solid libraries
4. **Idempotent migrations** prevent duplicate table errors
5. **BuildKit cache mounts** dramatically speed up builds
6. **Puma must bind to 0.0.0.0** for Docker networking
7. **Stdout logging with $stdout.sync** makes logs visible in Coolify
8. **SemanticLogger.reopen required** in `on_worker_boot` for Puma clustered mode

### Next Steps

- Customize this guide for your specific app
- Add monitoring (e.g., Sentry, New Relic)
- Set up automated backups
- Configure CI/CD (GitHub Actions)
- Scale horizontally by adding more workers

### Resources

- [Rails 8 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Coolify Documentation](https://coolify.io/docs)
- [Traefik Docker Provider](https://doc.traefik.io/traefik/providers/docker/)
- [Solid Queue Documentation](https://github.com/basecamp/solid_queue)
- [Solid Cache Documentation](https://github.com/rails/solid_cache)
- [Docker BuildKit](https://docs.docker.com/build/buildkit/)

---

**Document Version**: 1.0
**Last Updated**: 2025-11-19
**Tested With**: Rails 8.0.2, Ruby 3.4.2, Coolify 4.x
