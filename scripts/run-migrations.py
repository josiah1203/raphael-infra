#!/usr/bin/env python3
"""Run shared Raphael Postgres migrations (compose init hook)."""

from raphael_contracts.db import run_migrations

if __name__ == "__main__":
    run_migrations()
    print("migrations complete")
