# BF-SQLite toolchain: builds bf2c and compilers from scratch.
# For BF-only developers: you edit .bf; the container provides everything else.
#
# Build from the project root with `./bin/build-image`.
# Then run commands with `./bin/run-bf-db`, `./bin/run-tests`, or `./bin/shell`.

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ca-certificates \
    clang \
    git \
    python3 \
    sqlite3 \
    xxd \
    && rm -rf /var/lib/apt/lists/*

# Build bf2c from brainfuck-compiler-c
WORKDIR /tmp
RUN git clone --depth 1 https://github.com/yoshi389111/brainfuck-compiler-c.git \
    && cd brainfuck-compiler-c && make && cp bf2c /usr/local/bin/ \
    && cd / && rm -rf /tmp/brainfuck-compiler-c

# Phases 4-8 need clang -O0 (gcc segfaults on huge generated C)
ENV GCC="clang -O0"
ENV BF2C=bf2c

WORKDIR /work

# Pre-build phases and create tiny.db (build from repo root: docker build -f tools/Dockerfile .)
COPY . /work/
RUN if [ -f /work/tests/fixtures/tiny.sql.txt ]; then \
      sqlite3 /work/tests/fixtures/tiny.db < /work/tests/fixtures/tiny.sql.txt; \
    fi \
    && /work/scripts/build_bf.sh 2>/dev/null || true

CMD ["bash"]
