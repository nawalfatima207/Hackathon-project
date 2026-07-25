from faster_whisper import WhisperModel
import os

def format_timestamp(seconds):
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    secs = int(seconds % 60)
    if hours > 0:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"

def transcribe_audio(file_path):
    video_id = os.path.splitext(os.path.basename(file_path))[0]

    model = WhisperModel("base", device="cpu", compute_type="int8", cpu_threads=6)
    segments, info = model.transcribe(file_path, beam_size=1, vad_filter=True)

    lines = []
    for segment in segments:
        start_fmt = format_timestamp(segment.start)
        end_fmt = format_timestamp(segment.end)
        line = f"[{start_fmt} -> {end_fmt}] {segment.text}"
        print(line)
        lines.append(line)

    os.makedirs("transcripts", exist_ok=True)
    output_path = f"transcripts/{video_id}.txt"
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"\nSaved to {output_path}")
    return output_path

if __name__ == "__main__":
    path = input("Path to audio file: ")
    transcribe_audio(path)