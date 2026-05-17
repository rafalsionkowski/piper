"""
Piper TTS — HTTP wrapper dla LingoDrop.

POST /synthesize   body: {"text": "...", "language": "en"}  → audio/wav
GET  /health                                                → {"ok": true}
"""

import logging
import os
import subprocess
import tempfile

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Piper TTS", version="1.0.0")

PIPER_BIN  = os.getenv("PIPER_BIN",   "/app/piper")
MODELS_DIR = os.getenv("MODELS_DIR",  "/app/models")

# Mapowanie język → nazwa modelu ONNX
VOICE_MAP: dict[str, str] = {
    "en": "en_US-lessac-medium",
    "de": "de_DE-thorsten-medium",
    "fr": "fr_FR-siwis-medium",
    "es": "es_ES-davefx-medium",
}


class SynthRequest(BaseModel):
    text: str
    language: str = "en"


@app.get("/health")
def health() -> dict:
    return {"ok": True}


@app.post("/synthesize")
def synthesize(req: SynthRequest) -> Response:
    """Zamienia tekst na mowę i zwraca plik WAV."""

    voice = VOICE_MAP.get(req.language, VOICE_MAP["en"])
    model_path = os.path.join(MODELS_DIR, f"{voice}.onnx")

    if not os.path.exists(model_path):
        logger.error(f"Model nie znaleziony: {model_path}")
        raise HTTPException(
            status_code=503,
            detail=f"Voice model '{voice}' not found. Check MODELS_DIR.",
        )

    if not req.text.strip():
        raise HTTPException(status_code=400, detail="Text is empty.")

    # Zapisz WAV do pliku tymczasowego (piper nie potrafi pisać na stdout WAV)
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
        out_path = tmp.name

    try:
        logger.info(f"Synteza: voice={voice}, chars={len(req.text)}")
        result = subprocess.run(
            [PIPER_BIN, "--model", model_path, "--output_file", out_path],
            input=req.text.encode("utf-8"),
            capture_output=True,
            timeout=120,
        )

        if result.returncode != 0:
            err = result.stderr.decode(errors="replace")
            logger.error(f"Piper error (rc={result.returncode}): {err}")
            raise HTTPException(status_code=500, detail=f"Piper synthesis failed: {err}")

        with open(out_path, "rb") as f:
            audio_bytes = f.read()

        if len(audio_bytes) < 100:
            raise HTTPException(status_code=500, detail="Piper returned empty audio.")

        logger.info(f"Synteza OK: {len(audio_bytes)} bytes WAV")
        return Response(
            content=audio_bytes,
            media_type="audio/wav",
            headers={"Content-Length": str(len(audio_bytes))},
        )

    finally:
        if os.path.exists(out_path):
            os.unlink(out_path)
