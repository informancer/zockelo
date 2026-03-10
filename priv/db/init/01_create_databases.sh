#!/bin/bash
# Creates the EventStore database alongside the main Zockelo database.
# Runs automatically on first postgres container start.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE DATABASE zockelo_eventstore_prod OWNER $POSTGRES_USER;
  CREATE DATABASE glitchtip OWNER $POSTGRES_USER;
EOSQL
