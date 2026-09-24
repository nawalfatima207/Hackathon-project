from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from pipeline import (
    download_audio, transcribe_audio_router, group_into_chunks, embed_chunks,
    load_processed_data, save_processed_data, summarize, ask_question,
    format_timestamp, progress_log, reset_progress,
    reset_interrupt, request_interrupt, PipelineInterrupted
)

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

sessions = {}


class ProcessRequest(BaseModel):
    url: str
    model_choice: str = "ollama"
    engine: str = "groq"           # "groq" or "whisper"
    language: str | None = None    # spoken audio language, e.g. "ur"; None = auto-detect


class QuestionRequest(BaseModel):
    video_title: str
    question: str
    model_choice: str = "ollama"
    user_preferences: str = ""
    response_language: str = "auto"   # "auto" matches the question's language; or force e.g. "English"


class SummaryRequest(BaseModel):
    video_title: str
    model_choice: str = "ollama"
    response_language: str | None = None   # None = defaults to English in pipeline


@app.post("/process")
def process_video(req: ProcessRequest):
    reset_progress()
    reset_interrupt()
    print(f"[server] /process engine={req.engine!r} language={req.language!r}")
    try:
        video_title, audio_path = download_audio(req.url)

        segments, chunks = load_processed_data(video_title)
        if chunks is None:
            segments = transcribe_audio_router(
                audio_path, engine=req.engine, language=req.language
            )
            chunks = group_into_chunks(segments)
            chunks = embed_chunks(chunks)
            save_processed_data(video_title, segments, chunks)
        else:
            print(f"[server] Loaded cached transcript + embeddings.")

        sessions[video_title] = {
            "chunks": chunks,
            "history": [],
        }
        duration = format_timestamp(segments[-1]['end']) if segments else "0:00"

        return {"video_title": video_title, "duration": duration}
    except PipelineInterrupted:
        return {"error": "Cancelled."}


@app.post("/summarize")
def get_summary(req: SummaryRequest):
    reset_progress()
    reset_interrupt()
    try:
        session = sessions.get(req.video_title)

        if not session:
            segments, chunks = load_processed_data(req.video_title)
            if chunks is None:
                return {"error": "Video not processed yet. Call /process first."}
            session = {"chunks": chunks, "history": []}
            sessions[req.video_title] = session

        summary = summarize(
            session["chunks"], req.model_choice,
            response_language=req.response_language or "English",
        )
        return {"summary": summary}
    except PipelineInterrupted:
        return {"error": "Cancelled."}


@app.post("/ask")
def ask(req: QuestionRequest):
    reset_progress()
    reset_interrupt()
    try:
        session = sessions.get(req.video_title)
        if not session:
            return {"error": "Video not processed yet. Call /process first."}

        answer = ask_question(
            req.question, session["chunks"], session["history"],
            req.user_preferences, req.model_choice,
            response_language=req.response_language,
        )
        session["history"].append({"question": req.question, "answer": answer})
        return {"answer": answer}
    except PipelineInterrupted:
        return {"error": "Cancelled."}


@app.post("/interrupt")
def interrupt():
    request_interrupt()
    return {"ok": True}


@app.get("/progress")
def get_progress():
    return {"log": progress_log}


@app.get("/")
def health_check():
    return {"status": "running"}