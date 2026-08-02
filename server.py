from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from pipeline import (
    download_audio, transcribe_audio, group_into_chunks, embed_chunks,
    load_processed_data, save_processed_data, summarize, ask_question,
    format_timestamp, progress_log, reset_progress
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

class QuestionRequest(BaseModel):
    video_title: str
    question: str
    model_choice: str = "ollama"
    user_preferences: str = ""

class SummaryRequest(BaseModel):
    video_title: str
    model_choice: str = "ollama"

@app.post("/process")
def process_video(req: ProcessRequest):
    reset_progress()
    video_title, audio_path = download_audio(req.url)

    segments, chunks = load_processed_data(video_title)
    if chunks is None:
        segments = transcribe_audio(audio_path)
        chunks = group_into_chunks(segments)
        chunks = embed_chunks(chunks)
        save_processed_data(video_title, segments, chunks)

    sessions[video_title] = {"chunks": chunks, "history": []}
    duration = format_timestamp(segments[-1]['end']) if segments else "0:00"

    return {"video_title": video_title, "duration": duration}

@app.post("/summarize")
def get_summary(req: SummaryRequest):
    reset_progress()
    session = sessions.get(req.video_title)

    if not session:
        segments, chunks = load_processed_data(req.video_title)
        if chunks is None:
            return {"error": "Video not processed yet. Call /process first."}
        session = {"chunks": chunks, "history": []}
        sessions[req.video_title] = session

    summary = summarize(session["chunks"], req.model_choice)
    return {"summary": summary}

@app.post("/ask")
def ask(req: QuestionRequest):
    reset_progress()
    session = sessions.get(req.video_title)
    if not session:
        return {"error": "Video not processed yet. Call /process first."}

    answer = ask_question(
        req.question, session["chunks"], session["history"],
        req.user_preferences, req.model_choice
    )
    session["history"].append({"question": req.question, "answer": answer})
    return {"answer": answer}

@app.get("/progress")
def get_progress():
    return {"log": progress_log}

@app.get("/")
def health_check():
    return {"status": "running"}