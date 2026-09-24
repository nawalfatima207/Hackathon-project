Zylo — AI Lecture Assistant

CodeStorm Hackathon 2026 Submission Category: App Development

Problem Statement

Before exams, students are often given long recorded lectures to watch — sometimes hours long — with no easy way to search or ask about specific parts of the content. Our team faced exactly this: a database course teacher shared a very long lecture video to watch before the paper, and going through the whole thing wasted a huge amount of time that could have gone into actual studying.

Most students either watch the entire video passively or skip it altogether, missing important concepts.
We have experienced it personally as well.

Proposed Solution

Zylo (AI Lecture Assistant) lets a student paste a YouTube lecture link, and the app:

Downloads and transcribes the full lecture.
Lets the student ask questions about the lecture content in a chat interface — not just get a generic summary, but get direct, cited answers with timestamps.

This turns a long passive video into something a student can actually query, the same way they'd ask a classmate "what did the teacher say about normalization?"

Tech Stack
Layer	Technology
Frontend	Flutter
Backend	FastAPI
Video Download	yt-dlp + FFmpeg
Transcription	faster-whisper (base model, int8, CPU-optimized)
LLM (Q&A / Summarization)	Ollama running qwen2.5:3b (local), with Google Gemini API as a selectable alternative
Embeddings / RAG	nomic-embed-text, cached per video as JSON
Storage	Firestore
Project Structure
server.py             # FastAPI backend entry point
yt_assistant.py       # Handles YouTube video download
transcribe.py         # Handles transcription
rag_qa.py             # Embedding + question answering logic
transcripts/          # Per-video transcript storage
embeddings/           # Per-video cached embeddings (JSON)
How It Works
The user submits a YouTube lecture link.
The backend downloads the video/audio via yt-dlp + FFmpeg.
The audio is transcribed using faster-whisper, producing timestamped text (H:MM:SS format).
The transcript is embedded (nomic-embed-text) and cached per video.
When the user asks a question, the RAG pipeline retrieves relevant transcript sections and passes them, along with the last 5 conversation exchanges and a user-preference field, to the LLM (Ollama/qwen2.5:3b or Gemini) for a personalized, cited answer.
Setup & Installation
Clone the repository.
Install Python dependencies: pip install -r requirements.txt
Install Ollama and pull the model: ollama pull qwen2.5:3b
Ensure FFmpeg is installed and available on PATH.
Set up Firebase/Firestore credentials.
Run the backend: python -m uvicorn server:app --host 0.0.0.0 --port 8000
Run the Flutter app: flutter run
Running the Demo
Launch the backend server.
Open the Flutter app.
Paste a YouTube lecture link and wait for transcription to complete.
Ask questions about the lecture in the chat interface.
Known Limitations
Videos without audio cannot be transcribed — the app relies entirely on audio for transcription.
It's not yet confirmed whether the app reliably distinguishes which speaker said what in a two-person dialogue (speaker diarization is not fully verified).
yt-dlp needs to be updated regularly to keep working, since YouTube changes frequently break older versions.
Gemini API works correctly when tested directly via FastAPI /docs, but currently returns a "could not reach server" error when selected from within the Flutter app (Ollama/qwen2.5:3b works fine in-app).
Multi-language transcription (Urdu/Hindi) is planned but not yet implemented — important since many Pakistani lecturers teach in these languages.
Team
Nawal Fatima
Amna Ashfaq
Minahil Sajjad
Areeba Tariq
