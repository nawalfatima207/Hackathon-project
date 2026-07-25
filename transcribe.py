from faster_whisper import WhisperModel

def transcribe_audio(file_path):
    model = WhisperModel("base", device="cpu", compute_type="int8")
    segments, info = model.transcribe(file_path)

    lines = []
    for segment in segments:
        line = f"[{segment.start:.1f}s -> {segment.end:.1f}s] {segment.text}"
        print(line)
        lines.append(line)

    return "\n".join(lines)

if __name__ == "__main__":
    path = input("Path to audio file: ")
    text = transcribe_audio(path)
    with open("transcript.txt", "w", encoding="utf-8") as f:
        f.write(text)
    print("\nSaved to transcript.txt")