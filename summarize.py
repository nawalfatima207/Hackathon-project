import requests

def load_transcript(transcript_path="transcript.txt"):
    with open(transcript_path, "r", encoding="utf-8") as f:
        return f.read()

def ask_question(transcript, question):
    prompt = f"""You are answering questions about a lecture video based on its transcript.And try avoiding the word of transcript and mention video instead. 

The video may contain minor transcription errors — use context to infer the correct meaning where reasonable.

Answer the question clearly and directly, using only information from the transcript. If the transcript doesn't contain enough information to answer, say so honestly rather than guessing.

Transcript of the video:
{transcript}

Question: {question}

Answer:"""

    response = requests.post(
        "http://localhost:11434/api/generate",
        json={
            "model": "qwen2.5:3b",
            "prompt": prompt,
            "stream": False
        }
    )

    return response.json()["response"]

if __name__ == "__main__":
    transcript = load_transcript()

    print("Ask questions about the video (type 'exit' to quit)\n")
    while True:
        question = input("Your question: ")
        if question.lower() == "exit":
            break
        answer = ask_question(transcript, question)
        print(f"\nAnswer: {answer}\n")
