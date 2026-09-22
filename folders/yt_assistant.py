import yt_dlp

def download_audio(url, output_path="downloads/%(id)s.%(ext)s"):
    ydl_opts = {
        'format': 'bestaudio/best',
        'outtmpl': output_path,
        'ffmpeg_location': r"C:\Users\User\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1.2-full_build\bin",
        'postprocessors': [{
            'key': 'FFmpegExtractAudio',
            'preferredcodec': 'mp3',
            'preferredquality': '192',
        }],
    }

    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(url, download=True)
        video_id = info['id']

    return video_id

if __name__ == "__main__":
    url = input("Paste YouTube link: ")
    video_id = download_audio(url)
    print(f"Done! Video ID: {video_id}")