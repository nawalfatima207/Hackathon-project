import yt_dlp
import requests
import re
import numpy as np
import json
import threading
import time
import sys
import glob
import tempfile
import subprocess
from concurrent.futures import ThreadPoolExecutor
from faster_whisper import WhisperModel
from google import genai as google_genai
from groq import Groq
from dotenv import load_dotenv
import os

load_dotenv()
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
GROQ_API_KEY = os.environ.get("GROQ_API_KEY")
print("Gemini key loaded:", bool(GEMINI_API_KEY))
print("Groq key loaded:", bool(GROQ_API_KEY))
genai_client = google_genai.Client(api_key=GEMINI_API_KEY)
groq_client = Groq(api_key=GROQ_API_KEY, max_retries=2, timeout=120.0)

FFMPEG_PATH = r"C:\Users\User\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin"
FFMPEG_EXE = os.path.join(FFMPEG_PATH, "ffmpeg.exe")
FFPROBE_EXE = os.path.join(FFMPEG_PATH, "ffprobe.exe")

# Groq / transcription settings
GROQ_CHUNK_SECONDS = 600   # 10-minute pieces (~3.5 MB each at 48 kbps)
GROQ_MAX_WORKERS = 4       # concurrent uploads; lower if you see 429 errors
EMBED_WORKERS = 4          # concurrent embedding requests to Ollama
DEFAULT_ENGINE = "groq"    # "groq" or "whisper"

SUPPORTED_LANGUAGES = {
    "en": "English",
    "ur": "Urdu",
    "hi": "Hindi",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "arb": "Arabic",
    "ur-roman": "Roman Urdu",
    "auto": "Auto-detect",
}

# Whisper needs real ISO codes; your UI keys aren't all valid ones.
# None = let Whisper auto-detect.
TRANSCRIBE_LANG_MAP = {
    "auto": None,
    "arb": "ar",
    "ur-roman": "ur",
}

def to_whisper_language(code):
    if not code:
        return None
    code = code.lower()
    return TRANSCRIBE_LANG_MAP.get(code, code)

YDL_COMMON_OPTS = {
    'extractor_args': {
        'youtube': {
            'player_client': ['android', 'ios'],
        }
    },
    'http_headers': {
        'User-Agent': 'com.google.android.youtube/19.29.37 (Linux; U; Android 14) gzip'
    },
}

# ---------- Progress log (shared with server.py) ----------
progress_log = []

def log_progress(message, replace_last=False):
    if replace_last and progress_log:
        progress_log[-1] = message
    else:
        progress_log.append(message)

def reset_progress():
    progress_log.clear()

# ---------- Interruption ----------
# Cooperative cancellation: a flag checked between steps (chunks, segments,
# subprocess calls), PLUS real OS-level termination for anything running as
# a subprocess (ffmpeg). A live network call already in flight (a single
# Groq/Gemini/Ollama request) can't be aborted mid-request from here -- the
# flag is checked right before and right after each one instead, so at most
# one in-flight call finishes before the pipeline actually stops.

class PipelineInterrupted(Exception):
    """Raised internally when a stop request comes in; caught in server.py."""
    pass

_interrupt_event = threading.Event()
_process_lock = threading.Lock()
_current_process = None  # the currently-running subprocess.Popen, if any

def reset_interrupt():
    """Call at the start of every new /process, /summarize, /ask request."""
    _interrupt_event.clear()

def request_interrupt():
    """Call from the /interrupt endpoint. Flips the flag AND kills whatever
    subprocess (ffmpeg) is running right now, for an immediate stop."""
    _interrupt_event.set()
    with _process_lock:
        if _current_process is not None and _current_process.poll() is None:
            try:
                _current_process.terminate()
            except Exception:
                pass

def check_interrupt():
    if _interrupt_event.is_set():
        raise PipelineInterrupted("Cancelled by user.")

def _track_process(proc):
    global _current_process
    with _process_lock:
        _current_process = proc

def _untrack_process():
    global _current_process
    with _process_lock:
        _current_process = None

# ---------- Model switch ----------

def call_llm(prompt, model_choice="ollama"):
    if model_choice == "gemini":
        response = genai_client.models.generate_content(
            model="gemini-3.5-flash-lite",
            contents=prompt
        )
        return response.text

    response = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": "qwen2.5:3b",
            "prompt": prompt,
            "stream": False,
            "options": {"num_ctx": 8192, "num_predict": 800}
        }
    )
    result = response.json()
    if "error" in result:
        return f"(Error: {result['error']})"
    return result.get("response", "").strip() or "(Empty response)"


def sanitize_filename(name):
    return re.sub(r'[\\/*?:"<>|]', "", name).strip()

def show_loading(stop_event, label="Loading"):
    while not stop_event.is_set():
        for dots in range(4):
            if stop_event.is_set():
                break
            sys.stdout.write(f"\r{label}{'.' * dots}   ")
            sys.stdout.flush()
            time.sleep(0.4)
    sys.stdout.write("\r" + " " * 30 + "\r")

# ---------- Download ----------
def _ydl_interrupt_hook(d):
    check_interrupt()

def download_audio(url):
    check_interrupt()
    log_progress("Fetching video info...")
    info_opts = {'quiet': True, **YDL_COMMON_OPTS}
    with yt_dlp.YoutubeDL(info_opts) as ydl:
        info = ydl.extract_info(url, download=False)
        video_title = sanitize_filename(info['title'])

    check_interrupt()
    audio_path = f"downloads/{video_title}.mp3"
    if os.path.exists(audio_path):
        log_progress("Audio already downloaded, skipping.")
        return video_title, audio_path

    log_progress("Downloading audio...")
    ydl_opts = {
        'socket_timeout': 30,
        'retries': 10,
        'format': 'bestaudio/best',
        'outtmpl': f'downloads/{video_title}.%(ext)s',
        'ffmpeg_location': FFMPEG_PATH,
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
        'progress_hooks': [_ydl_interrupt_hook],
        **YDL_COMMON_OPTS,
    }
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
    except Exception:
        # If we were the ones who raised (via the progress hook), surface
        # that clearly instead of whatever yt-dlp wrapped it in.
        check_interrupt()
        raise

    log_progress("Download complete.")
    return video_title, audio_path

# ---------- Timestamps ----------
def format_timestamp(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"

# ---------- File readiness check ----------

def wait_for_file_ready(path, timeout=10, interval=0.5):
    """Wait until a file can be opened (i.e. no other process has it locked)."""
    elapsed = 0
    while elapsed < timeout:
        try:
            with open(path, "rb"):
                return True
        except PermissionError:
            time.sleep(interval)
            elapsed += interval
    raise PermissionError(f"File still locked after {timeout}s: {path}")

# ---------- Transcription: local Whisper ----------
_local_model = None

def get_local_model():
    """Load the local model once, only when actually needed."""
    global _local_model
    if _local_model is None:
        _local_model = WhisperModel("base", device="cpu", compute_type="int8", cpu_threads=6)
    return _local_model

def transcribe_audio(file_path, language=None):
    check_interrupt()
    log_progress("Transcribing audio (local)...")
    t0 = time.perf_counter()
    model = get_local_model()
    segments, info = model.transcribe(
        file_path, beam_size=1, vad_filter=True,
        language=to_whisper_language(language),
    )
    result = []
    for s in segments:
        # segments is a lazy generator -- each iteration decodes the next
        # chunk of audio, so this check actually stops mid-transcription
        # instead of only between whole-file calls.
        check_interrupt()
        result.append({"start": s.start, "end": s.end, "text": s.text})
    log_progress(f"Transcription complete (local) in {time.perf_counter() - t0:.1f}s.")
    return result

# ---------- Transcription: Groq ----------
def _run(cmd):
    check_interrupt()
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    _track_process(proc)
    try:
        _, stderr = proc.communicate()
    finally:
        _untrack_process()
    if proc.returncode != 0:
        # A non-zero return from a process we just terminated ourselves
        # means this was a cancellation, not a real ffmpeg failure.
        check_interrupt()
        raise RuntimeError(f"Command failed: {cmd[0]}\n{(stderr or '')[-500:]}")

def _duration(path):
    check_interrupt()
    out = subprocess.run(
        [FFPROBE_EXE, "-v", "error", "-show_entries", "format=duration",
         "-of", "default=noprint_wrappers=1:nokey=1", path],
        capture_output=True, text=True, check=True,
    )
    return float(out.stdout.strip())

def _prepare_chunks(file_path, work_dir):
    """Compress to 16 kHz mono MP3, split into chunks. Returns [(path, offset_seconds)]."""
    compressed = os.path.join(work_dir, "audio.mp3")
    _run([FFMPEG_EXE, "-y", "-i", file_path, "-vn", "-ac", "1", "-ar", "16000",
          "-b:a", "48k", compressed])

    _run([FFMPEG_EXE, "-y", "-i", compressed, "-f", "segment",
          "-segment_time", str(GROQ_CHUNK_SECONDS), "-c", "copy",
          "-reset_timestamps", "1",
          os.path.join(work_dir, "chunk_%03d.mp3")])

    chunks, offset = [], 0.0
    for p in sorted(glob.glob(os.path.join(work_dir, "chunk_*.mp3"))):
        check_interrupt()
        chunks.append((p, offset))
        offset += _duration(p)
    return chunks

def _transcribe_one(chunk_path, offset, language):
    check_interrupt()

    with open(chunk_path, "rb") as f:
        audio_bytes = f.read()

    kwargs = {
        "file": (os.path.basename(chunk_path), audio_bytes),
        "model": "whisper-large-v3-turbo",
        "response_format": "verbose_json",
    }

    if language:
        kwargs["language"] = language

    response = groq_client.audio.transcriptions.create(**kwargs)
    check_interrupt()

    segments = getattr(response, "segments", None)
    detected_language = getattr(response, "language", None)

    if isinstance(response, dict):
        if segments is None:
            segments = response.get("segments", [])
        detected_language = response.get("language", detected_language)

    out = []

    for s in segments or []:
        if isinstance(s, dict):
            start, end, text = s["start"], s["end"], s["text"]
        else:
            start, end, text = s.start, s.end, s.text

        out.append({
            "start": start + offset,
            "end": end + offset,
            "text": text
        })

    return out, detected_language

def transcribe_audio_groq(file_path, language=None):
    """Groq-hosted Whisper. language: UI code ('ur', 'auto', ...) or None for auto-detect."""
    
    check_interrupt()
    log_progress("Transcribing audio (Groq)...")
    t_total = time.perf_counter()

    lang = to_whisper_language(language)

    with tempfile.TemporaryDirectory() as work_dir:

        t0 = time.perf_counter()

        chunks = _prepare_chunks(file_path, work_dir)

        print(
            f"[timing] compress + split: "
            f"{time.perf_counter() - t0:.1f}s ({len(chunks)} chunks)"
        )

        t0 = time.perf_counter()

        with ThreadPoolExecutor(max_workers=GROQ_MAX_WORKERS) as pool:

            futures = [
                pool.submit(_transcribe_one, p, off, lang)
                for p, off in chunks
            ]

            try:
                parts = [f.result() for f in futures]

            except PipelineInterrupted:
                for fut in futures:
                    fut.cancel()

                pool.shutdown(
                    wait=False,
                    cancel_futures=True
                )

                raise

        print(
            f"[timing] Groq API (all chunks): "
            f"{time.perf_counter() - t0:.1f}s"
        )

    # Combine segments from all chunks
    result = [
        seg
        for part, _lang in parts
        for seg in part
    ]

    # Get detected language from the first chunk that returned one
    detected_language = next(
        (lang for _part, lang in parts if lang),
        None
    )

    log_progress(
        f"Transcription complete (Groq) "
        f"in {time.perf_counter() - t_total:.1f}s."
    )

    return result, detected_language


def transcribe_audio_router(file_path, engine=DEFAULT_ENGINE, language=None):
    print(f"[router] engine={engine!r}, language={language!r}")
    """'groq' (cloud, fast) or 'whisper' (local). Falls back to local if Groq fails."""
    check_interrupt()
    if engine == "groq":
        try:
            return transcribe_audio_groq(file_path, language=language)
        except PipelineInterrupted:
            raise
        except Exception as e:
            print(f"[groq error] {e}")
            log_progress("Groq failed, falling back to local Whisper...")
            return transcribe_audio(file_path, language=language)
    return transcribe_audio(file_path, language=language)

# ---------- RAG: chunking + embeddings ----------
def group_into_chunks(segments, chunk_duration=90.0):
    chunks = []
    current_chunk = {"start": None, "end": None, "text": ""}
    for seg in segments:
        if current_chunk["start"] is None:
            current_chunk["start"] = seg["start"]
        current_chunk["end"] = seg["end"]
        current_chunk["text"] += " " + seg["text"]
        if current_chunk["end"] - current_chunk["start"] >= chunk_duration:
            chunks.append(current_chunk)
            current_chunk = {"start": None, "end": None, "text": ""}
    if current_chunk["text"]:
        chunks.append(current_chunk)
    return chunks

def get_embedding(text):
    response = requests.post(
        "http://localhost:11434/api/embeddings",
        json={"model": "nomic-embed-text", "prompt": text},
        timeout=120,
    )
    data = response.json()
    if "embedding" not in data:
        raise ValueError(f"No embedding returned: {data.get('error', 'unknown error')}")
    return data["embedding"]

def embed_chunks(chunks):
    check_interrupt()
    total = len(chunks)
    log_progress(f"Embedding chunk 0/{total}...")
    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=EMBED_WORKERS) as pool:
        embeddings = pool.map(get_embedding, [c["text"] for c in chunks])  # ordered
        try:
            for i, (chunk, emb) in enumerate(zip(chunks, embeddings)):
                check_interrupt()
                chunk["embedding"] = emb
                log_progress(f"Embedding chunk {i+1}/{total}...", replace_last=True)
        except PipelineInterrupted:
            pool.shutdown(wait=False, cancel_futures=True)
            raise
    log_progress(f"Embedding complete in {time.perf_counter() - t0:.1f}s.")
    return chunks

def cosine_similarity(a, b):
    a, b = np.array(a), np.array(b)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def retrieve_relevant_chunks(question, chunks, top_k=3):
    question_embedding = get_embedding(question)
    scored = [(cosine_similarity(question_embedding, c["embedding"]), c) for c in chunks]
    scored.sort(key=lambda x: x[0], reverse=True)
    return [c for _, c in scored[:top_k]]

# ---------- Persistence: one JSON file per video ----------
def save_processed_data(video_title, segments, chunks, detected_language):
    os.makedirs("data", exist_ok=True)

    with open(f"data/{video_title}.json", "w", encoding="utf-8") as f:
        json.dump(
            {
                "segments": segments,
                "chunks": chunks,
                "detected_language": detected_language
            },
            f,
            ensure_ascii=False,
            indent=2
        )
def load_processed_data(video_title):
    path = f"data/{video_title}.json"

    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)

        return (
            data["segments"],
            data["chunks"],
            data.get("detected_language")
        )

    return None, None, None
def save_transcript_as_text(video_title, segments):
    os.makedirs("transcripts", exist_ok=True)
    lines = [f"[{format_timestamp(s['start'])} -> {format_timestamp(s['end'])}] {s['text']}" for s in segments]
    path = f"transcripts/{video_title}.txt"
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Transcript saved to {path}")

# ---------- Summarization (on request only) ----------
def summarize(
    chunks,
    model_choice="ollama",
    response_language="English",
    detected_language=None
):
    check_interrupt()
    log_progress("Generating summary...")
    full_text = " ".join(c["text"] for c in chunks)
    prompt = f"""You are summarizing a video into clear, structured study notes.

Start with a brief note that this is a summary of a lecture video.

Produce:
1. Video Overview - 1-2 sentences
2. Key Points - bullet points by topic
3. Key Terms & Definitions - anything important mentioned

Answer strictly in {response_language}.Do not make up any information. Only summarize what is present in the transcript.
Transcript:
{full_text}
"""
    result = call_llm(prompt, model_choice)
    log_progress("Summary ready.")
    return result

# ---------- Q&A ----------
def ask_question(question, chunks, history, user_preferences="", model_choice="ollama", response_language="English"):
    check_interrupt()
    log_progress("Thinking...")
    relevant = retrieve_relevant_chunks(question, chunks)
    context = "\n\n".join(
        f"[{format_timestamp(c['start'])} -> {format_timestamp(c['end'])}] {c['text']}"
        for c in relevant
    )

    history_text = ""
    if history:
        history_text = "Previous conversation:\n" + "\n".join(
            f"Q: {h['question']}\nA: {h['answer']}" for h in history[-5:]
        ) + "\n\n"

    pref_text = f"User preference: {user_preferences}\n\n" if user_preferences else ""

    prompt = f"""You are answering questions about a video using only the relevant transcript excerpts below.

{pref_text}{history_text}Cite the timestamp(s) you used in this format: (source: 12:14-12:45)

provide as much assistance as possible related to the topics discussed in the video even tho the detail is not present in the video
avoid answering questions that are not related to the video content.
And provide the answer in {response_language}.

Relevant excerpts:
{context}

Question: {question}

Answer (with timestamp citation):"""

    result = call_llm(prompt, model_choice)
    log_progress("Answer ready.")
    return result

# ---------- Main pipeline (terminal mode) ----------
if __name__ == "__main__":
    url = input("Paste YouTube link: ")
    video_title, audio_path = download_audio(url)

    segments, chunks = load_processed_data(video_title)

    if chunks is None:
        lang_code = input("Audio language code (Enter for auto-detect, e.g. ur, en): ").strip() or None
        wait_for_file_ready(audio_path)
        segments = transcribe_audio_router(audio_path, engine=DEFAULT_ENGINE, language=lang_code)  # <-- was transcribe_audio()
        chunks = group_into_chunks(segments)
        chunks = embed_chunks(chunks)
        save_processed_data(video_title, segments, chunks)
    else:
        print("Loaded cached transcript + embeddings.")

    save_txt = input("Also save transcript as a plain text file? (y/n): ")
    if save_txt.lower() == "y":
        save_transcript_as_text(video_title, segments)

    user_preferences = input("Any preference for how I explain things? (Enter to skip): ")
    print("Supported languages:", ", ".join(SUPPORTED_LANGUAGES.values()))
    lang_input = input("Response language (Enter for English): ").strip()
    response_language = SUPPORTED_LANGUAGES.get(lang_input.lower(), "English")
    print("\nReady. Ask a question ('exit' to quit).\n")

    history = []
    while True:
        question = input("You: ")
        if question.lower() == "exit":
            break
        if question.lower() == "summary":
            print("\n--- Summary ---\n")
            print(summarize(chunks, response_language=response_language))
            print()
            continue
        answer = ask_question(question, chunks, history, user_preferences, response_language=response_language)
        print(f"\nAnswer: {answer}\n")
        history.append({"question": question, "answer": answer})