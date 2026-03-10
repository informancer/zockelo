# =============================================================================
# Multi-stage Dockerfile for Zockelo
# Elixir 1.18 / OTP 27 — Debian bookworm slim
# =============================================================================

ARG ELIXIR_VERSION=1.18.3
ARG OTP_VERSION=27.3
ARG DEBIAN_VERSION=bookworm-20250317-slim

ARG BUILD_IMAGE="hexpm/elixir:${ELIXIR_VERSION}-erlang-${OTP_VERSION}-debian-${DEBIAN_VERSION}"
ARG RUNTIME_IMAGE="debian:${DEBIAN_VERSION}"

# =============================================================================
# Stage 1: Build
# =============================================================================
FROM ${BUILD_IMAGE} AS build

# Install build-time system dependencies
RUN apt-get update -y \
  && apt-get install -y build-essential git curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Set build environment
ENV MIX_ENV=prod

# Install Elixir dependencies (cached separately from app code)
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config (not runtime.exs — that runs at startup)
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy and compile application code
COPY priv priv
COPY lib lib
COPY assets assets

# Build JS/CSS assets, then digest (fingerprint + gzip)
RUN mix assets.deploy

# Compile the application
RUN mix compile

# Build the release
ARG BUILD_HASH=dev
ENV BUILD_HASH=${BUILD_HASH}

COPY config/runtime.exs config/
RUN mix release

# =============================================================================
# Stage 2: Runtime
# =============================================================================
FROM ${RUNTIME_IMAGE} AS runtime

# Install runtime dependencies only
RUN apt-get update -y \
  && apt-get install -y libstdc++6 openssl libncurses5 locales curl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

# Copy the release from the build stage
COPY --from=build --chown=nobody:root /app/_build/prod/rel/zockelo ./

USER nobody

ENV MIX_ENV=prod
ENV PHX_SERVER=true

# Run migrations before starting the server
ENTRYPOINT ["/app/bin/zockelo"]
CMD ["start"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:4000/health || exit 1

EXPOSE 4000
