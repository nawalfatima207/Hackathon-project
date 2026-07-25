import requests
import re
import numpy as np
import threading
import time
import sys

def load_transcript_segments(transcript_path="transcript.txt"):
    segments = []
    pattern = r"\[(\d+\.?\d*)s -> (\d+\.?\d*)s\]\s*(.*)"

    with open(transcript_path, "r", encoding="utf-8") as f:
        for line in f:
            match = re.match(pattern, line.strip())
            if match:
                start, end, text = match.groups()
                segments.append({
                    "start": float(start),
                    "end": float(end),
                    "text": text
                })
    return segments

def group_into_chunks(segments, chunk_duration=30.0):
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

def show_loading(stop_event, label="Loading"):
    while not stop_event.is_set():
        for dots in range(4):
            if stop_event.is_set():
                break
            sys.stdout.write(f"\r{label}{'.' * dots}   ")
            sys.stdout.flush()
            time.sleep(0.4)
    sys.stdout.write("\r" + " " * 30 + "\r")

def get_embedding(text):
    response = requests.post(
        "http://localhost:11434/api/embeddings",
        json={"model": "nomic-embed-text", "prompt": text}
    )
    return response.json()["embedding"]

def embed_chunks(chunks):
    stop_event = threading.Event()
    loading_thread = threading.Thread(target=show_loading, args=(stop_event, "Embedding transcript"))
    loading_thread.start()

    for chunk in chunks:
        chunk["embedding"] = get_embedding(chunk["text"])

    stop_event.set()
    loading_thread.join()
    return chunks

def cosine_similarity(a, b):
    a, b = np.array(a), np.array(b)
    return np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b))

def retrieve_relevant_chunks(question, chunks, top_k=3):
    question_embedding = get_embedding(question)
    scored = [
        (cosine_similarity(question_embedding, chunk["embedding"]), chunk)
        for chunk in chunks
    ]
    scored.sort(key=lambda x: x[0], reverse=True)
    return [chunk for _, chunk in scored[:top_k]]

def ask_question(question, chunks):
    stop_event = threading.Event()
    loading_thread = threading.Thread(target=show_loading, args=(stop_event, "Thinking"))
    loading_thread.start()

    relevant = retrieve_relevant_chunks(question, chunks)

    context = "\n\n".join(
        f"[{c['start']:.1f}s -> {c['end']:.1f}s] {c['text']}" for c in relevant
    )

    prompt = f"""You are answering questions about a video using only the relevant transcript excerpts below.Try avaiding the word "transcript" in your answer instead use video.

Cite the timestamp(s) you used in this format: (source: 12.3s-15.7s)

Try providing as much assistance related to the topics in the excerpts, if asked. Also, honestly say no if the topic is not relavent to the excerpts.

Relevant excerpts:
{context}

Question: {question}

Answer (with timestamp citation):"""

    response = requests.post(
        "http://localhost:11434/api/generate",
        json={"model": "qwen2.5:3b", "prompt": prompt, "stream": False}
    )

    stop_event.set()
    loading_thread.join()

    return response.json()["response"]

if __name__ == "__main__":
    print("Loading transcript...")
    segments = load_transcript_segments()
    chunks = group_into_chunks(segments)
    print(f"Created {len(chunks)} chunks.")
    chunks = embed_chunks(chunks)
    print("Ready.\n")

    while True:
        question = input("Your question (or 'exit'): ")
        if question.lower() == "exit":
            break
        answer = ask_question(question, chunks)
        print(f"\nAnswer: {answer}\n")
