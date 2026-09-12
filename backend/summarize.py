import requests
import re
import numpy as np
import json
import os

def timestamp_to_seconds(ts):
    parts = [int(p) for p in ts.split(":")]
    if len(parts) == 3:
        h, m, s = parts
        return h * 3600 + m * 60 + s
    elif len(parts) == 2:
        m, s = parts
        return m * 60 + s
    return int(parts[0])

def seconds_to_timestamp(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"

def load_transcript_segments(transcript_path):
    segments = []
    pattern = r"\[(\d+(?::\d+)*) -> (\d+(?::\d+)*)\]\s*(.*)"

    with open(transcript_path, "r", encoding="utf-8") as f:
        for line in f:
            match = re.match(pattern, line.strip())
            if match:
                start, end, text = match.groups()
                segments.append({
                    "start": timestamp_to_seconds(start),
                    "end": timestamp_to_seconds(end),
                    "text": text
                })
    return segments

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
        json={"model": "nomic-embed-text", "prompt": text}
    )
    return response.json()["embedding"]

def embed_chunks(chunks, video_id):
    cache_path = f"transcripts/{video_id}_embeddings.json"

    if os.path.exists(cache_path):
        with open(cache_path, "r") as f:
            cached = json.load(f)
        if len(cached) == len(chunks):
            for i, chunk in enumerate(chunks):
                chunk["embedding"] = cached[i]
            print("Loaded embeddings from cache.")
            return chunks

    for i, chunk in enumerate(chunks):
        chunk["embedding"] = get_embedding(chunk["text"])
        print(f"\rEmbedding chunk {i+1}/{len(chunks)}...", end="", flush=True)
    print()

    with open(cache_path, "w") as f:
        json.dump([c["embedding"] for c in chunks], f)
    return chunks

def cosine_similarity(a, b):
    a, b = np.array(a), np.array(b)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def retrieve_relevant_chunks(question, chunks, top_k=3):
    question_embedding = get_embedding(question)
    scored = [(cosine_similarity(question_embedding, c["embedding"]), c) for c in chunks]
    scored.sort(key=lambda x: x[0], reverse=True)
    return [c for _, c in scored[:top_k]]

def ask_question(question, chunks, history, user_preferences=""):
    relevant = retrieve_relevant_chunks(question, chunks)

    context = "\n\n".join(
        f"[{seconds_to_timestamp(c['start'])} -> {seconds_to_timestamp(c['end'])}] {c['text']}"
        for c in relevant
    )

    history_text = ""
    if history:
        history_text = "Previous conversation:\n" + "\n".join(
            f"Q: {h['question']}\nA: {h['answer']}" for h in history[-5:]
        ) + "\n\n"

    pref_text = f"User preference: {user_preferences}\n\n" if user_preferences else ""

    prompt = f"""You are answering questions about a lecture video using only the relevant transcript excerpts below.

{pref_text}{history_text}Cite the timestamp(s) you used in this format: (source: 12:14-12:45)

Try providing as much assistance related to the topics in the excerpts, if asked. Also, honestly say no if the topic is not relavent to the excerpts.

Relevant excerpts:
{context}

Question: {question}

Answer (with timestamp citation):"""

    response = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": "qwen2.5:3b", "prompt": prompt, "stream": False}
    )
    return response.json()["response"]

if __name__ == "__main__":
    transcript_path = input("Path to transcript file: ")
    video_id = os.path.splitext(os.path.basename(transcript_path))[0]

    print("Loading transcript...")
    segments = load_transcript_segments(transcript_path)
    chunks = group_into_chunks(segments)
    print(f"Created {len(chunks)} chunks.")
    chunks = embed_chunks(chunks, video_id)

    user_preferences = input("Any preference for how I explain things? (Enter to skip): ")
    print("Ready.\n")

    history = []
    while True:
        question = input("Your question (or 'exit'): ")
        if question.lower() == "exit":
            break
        answer = ask_question(question, chunks, history, user_preferences)
        print(f"\nAnswer: {answer}\n")
        history.append({"question": question, "answer": answer})