FROM debian:bullseye as build
ARG TARGETARCH
ARG TARGETVARIANT

ENV LANG C.UTF-8
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        build-essential cmake ca-certificates curl pkg-config git

WORKDIR /build

COPY ./ ./
RUN cmake -Bbuild -DCMAKE_INSTALL_PREFIX=install
RUN cmake --build build --config Release
RUN cmake --install build

# Do a test run
RUN ./build/piper --help

# Build .tar.gz to keep symlinks
WORKDIR /dist
RUN mkdir -p piper && \
    cp -dR /build/install/* ./piper/ && \
    tar -czf "piper_${TARGETARCH}${TARGETVARIANT}.tar.gz" piper/

# -----------------------------------------------------------------------------

# FROM debian:bullseye as test
# ARG TARGETARCH
# ARG TARGETVARIANT

# WORKDIR /test

# COPY local/en-us/lessac/low/en-us-lessac-low.onnx \
#      local/en-us/lessac/low/en-us-lessac-low.onnx.json ./

# # Run Piper on a test sentence and verify that the WAV file isn't empty
# COPY --from=build /dist/piper_*.tar.gz ./
# RUN tar -xzf piper*.tar.gz
# RUN echo 'This is a test.' | ./piper/piper -m en-us-lessac-low.onnx -f test.wav
# RUN if [ ! -f test.wav ]; then exit 1; fi
# RUN size="$(wc -c < test.wav)"; \
#     if [ "${size}" -lt "1000" ]; then echo "File size is ${size} bytes"; exit 1; fi

# -----------------------------------------------------------------------------

FROM debian:bullseye-slim

RUN apt-get update && \
    apt-get install --yes --no-install-recommends \
        ca-certificates curl \
        python3 python3-pip && \
    rm -rf /var/lib/apt/lists/*

# Python HTTP wrapper dependencies
RUN pip3 install --no-cache-dir fastapi uvicorn[standard]

WORKDIR /app

COPY --from=build /dist/piper_*.tar.gz ./
RUN tar -xzf piper_*.tar.gz --strip-components=1 && \
    rm -f piper_*.tar.gz

# Pobierz modele głosowe ONNX dla en/de/fr/es
# Źródło: https://huggingface.co/rhasspy/piper-voices
RUN mkdir -p /app/models

RUN curl -fsSL -o /app/models/en_US-lessac-medium.onnx \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx" && \
    curl -fsSL -o /app/models/en_US-lessac-medium.onnx.json \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"

RUN curl -fsSL -o /app/models/de_DE-thorsten-medium.onnx \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx" && \
    curl -fsSL -o /app/models/de_DE-thorsten-medium.onnx.json \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/de/de_DE/thorsten/medium/de_DE-thorsten-medium.onnx.json"

RUN curl -fsSL -o /app/models/fr_FR-siwis-medium.onnx \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx" && \
    curl -fsSL -o /app/models/fr_FR-siwis-medium.onnx.json \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/fr/fr_FR/siwis/medium/fr_FR-siwis-medium.onnx.json"

RUN curl -fsSL -o /app/models/es_ES-davefx-medium.onnx \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx" && \
    curl -fsSL -o /app/models/es_ES-davefx-medium.onnx.json \
        "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/es/es_ES/davefx/medium/es_ES-davefx-medium.onnx.json"

# HTTP wrapper
COPY server.py ./

ENV LD_LIBRARY_PATH=/app
ENV PIPER_BIN=/app/piper
ENV MODELS_DIR=/app/models

EXPOSE 8080

CMD ["uvicorn", "server:app", "--host", "0.0.0.0", "--port", "8080"]
