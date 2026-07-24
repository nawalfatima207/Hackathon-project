from faster_whisper import WhisperModel

def transcribe_audio(file_path):
    model = WhisperModel("base", device="cpu", compute_type="int8")
    segments, info = model.transcribe(file_path)

    text = ""
    for segment in segments:
        print(f"[{segment.start:.1f}s -> {segment.end:.1f}s] {segment.text}")
        text += segment.text + " "

    return text

if __name__ == "__main__":
    path = input("Path to audio file: ")
    text = transcribe_audio(path)
    with open("transcript.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("\nSaved to transcript.txt")