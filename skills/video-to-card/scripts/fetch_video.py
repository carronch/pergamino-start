#!/usr/bin/env python3
"""video-to-card: fetch a video, transcribe it with whisper.cpp, and sample its frames.

Usage:
  fetch_video.py (SOURCE | --source-file FILE) [--info] [--out DIR] [--lang auto]
                 [--prompt TEXT] [--frames 16] [--captions] [--model PATH] [--threads N]
                 [--video-index 0] [--no-transcribe]
  fetch_video.py --segment START:SECONDS --out DIR [--prompt TEXT] [--lang auto]

SOURCE is an X (Twitter) post URL, any other URL that yt-dlp can fetch
(YouTube, Instagram, TikTok, Vimeo, ...), or a local video or audio file.
--source-file reads SOURCE from a file, so that an untrusted URL never sits
inside a shell command.

--info prints what the source is (title, author, length, captions, access
limits) and downloads nothing. Run it first when the length is unknown.

Everything else lands in --out (default /tmp/video-to-card/<slug>/). Each run first removes
what an earlier run left there (never the source file itself):
  manifest.json      what was fetched, from where, with which tools; warnings; an
                     "error" field when the run failed
  source.json        raw metadata (X embed + FxTwitter JSON, or yt-dlp info)
  media.<ext>        the downloaded media (X: the smallest file of 360p or more)
  audio.wav          16 kHz mono, the whisper input
  transcript.srt, transcript.txt, whisper.log   (or captions*.vtt with --captions)
  blocks.md          the transcript in blocks of about 45 seconds, each with its start time
  frames/f-NNN.jpg   evenly spaced frames
  sheets/sheet-N.jpg contact sheets of 8 frames; manifest.json gives each tile's time

--captions uses the platform's own captions (yt-dlp sources) instead of whisper:
for long videos, or when the platform refuses the media download. When the
media download fails, the script tries the captions by itself.

--segment re-transcribes one part of an existing audio.wav (for example with a
--prompt of names) and prints the text. It changes no file.

The script never writes into a brain. Network use: GET requests only, without
cookies. Python 3.9+ standard library; needs curl, ffmpeg and ffprobe, whisper-cli
and a ggml model, and yt-dlp for sources other than X and local files.
"""
import argparse
import datetime
import glob
import html
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

UA = ("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/124.0 Safari/537.36")
X_RE = re.compile(r"^https?://(?:www\.|mobile\.)?(?:x|twitter)\.com/([^/?#]+)/status(?:es)?/(\d+)", re.I)
FONTS = ["/System/Library/Fonts/Supplemental/Arial.ttf", "/Library/Fonts/Arial.ttf",
         "/System/Library/Fonts/Helvetica.ttc", "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"]
MODEL_GLOBS = ["/opt/homebrew/share/whisper-cpp/ggml-{m}.bin", "/usr/local/share/whisper-cpp/ggml-{m}.bin",
               "/opt/homebrew/Cellar/whisper*/*/share/whisper-cpp/ggml-{m}.bin",
               "/usr/local/Cellar/whisper*/*/share/whisper-cpp/ggml-{m}.bin",
               "~/.cache/whisper/ggml-{m}.bin", "~/.local/share/whisper/ggml-{m}.bin", "~/models/ggml-{m}.bin"]

warnings = []


class FetchError(Exception):
    pass


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def warn(msg):
    warnings.append(msg)
    log("warning: " + msg)


def run(cmd, **kw):
    """Run a command given as a list (never through a shell)."""
    return subprocess.run(cmd, check=True, capture_output=True, text=True, **kw)


def need(tool, hint):
    path = shutil.which(tool)
    if not path:
        raise FetchError(f"{tool} is not installed. {hint}")
    return path


def curl(args, timeout):
    """GET with curl: it uses the system certificates, which a python.org Python may lack."""
    r = subprocess.run(["curl", "-fsSL", "--max-time", str(timeout), "-A", UA] + args, capture_output=True)
    if r.returncode != 0:
        raise FetchError(f"curl exit {r.returncode}: {r.stderr.decode('utf-8', 'replace').strip()[:200]}")
    return r.stdout


def http_json(url, timeout=30):
    if shutil.which("curl"):
        return json.loads(curl(["-H", "Accept: application/json", url], timeout).decode("utf-8"))
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def download(url, path, timeout=900):
    if shutil.which("curl"):
        curl(["-o", path, url], timeout)
        return
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=timeout) as r, open(path, "wb") as f:
        shutil.copyfileobj(r, f, length=1 << 20)


def ffprobe(src):
    out = run(["ffprobe", "-v", "error", "-print_format", "json", "-show_format", "-show_streams", src]).stdout
    data = json.loads(out)
    video = next((s for s in data.get("streams", []) if s.get("codec_type") == "video"
                  and s.get("disposition", {}).get("attached_pic") != 1), None)
    audio = next((s for s in data.get("streams", []) if s.get("codec_type") == "audio"), None)
    dur = float(data.get("format", {}).get("duration") or 0)
    info = {"duration_s": round(dur, 2), "has_audio": audio is not None, "has_video": video is not None}
    if video:
        w, h = int(video.get("width") or 0), int(video.get("height") or 0)
        rot = str((video.get("tags") or {}).get("rotate", ""))
        for sd in video.get("side_data_list", []) or []:
            if "rotation" in sd:
                rot = str(sd["rotation"])
        if rot.lstrip("-") in ("90", "270"):
            w, h = h, w
        info.update({"width": w, "height": h})
    return info


def resolution(url):
    m = re.search(r"/(\d+)x(\d+)/", url)
    return (int(m.group(1)), int(m.group(2))) if m else (0, 0)


def stamp(t):
    t = int(t)
    return f"{t // 3600}:{t % 3600 // 60:02d}:{t % 60:02d}" if t >= 3600 else f"{t // 60}:{t % 60:02d}"


# ---------- X ----------

def x_token(tweet_id):
    """Token for X's public embed endpoint, computed the way the embed widget does."""
    node = shutil.which("node")
    if node:
        js = "console.log(((Number(process.argv[1])/1e15)*Math.PI).toString(36).replace(/(0+|\\.)/g,''))"
        try:
            return run([node, "-e", js, tweet_id]).stdout.strip()
        except (subprocess.CalledProcessError, OSError):
            pass
    return "a"


def x_lookup(user, tid, out, video_index):
    """Read the post; return (post, audio_url, frames_url). Downloads nothing."""
    synd, fx = None, None
    try:
        synd = http_json(f"https://cdn.syndication.twimg.com/tweet-result?id={tid}&lang=en&token={x_token(tid)}")
    except (FetchError, urllib.error.URLError, ValueError, OSError) as e:
        warn(f"X embed endpoint failed: {e}")
    try:
        fx = http_json(f"https://api.fxtwitter.com/{user}/status/{tid}")
    except (FetchError, urllib.error.URLError, ValueError, OSError) as e:
        warn(f"FxTwitter failed: {e}")
    if not synd and not fx:
        raise FetchError("Could not read the post from X's embed endpoint or FxTwitter.")
    if out:
        with open(os.path.join(out, "source.json"), "w") as f:
            json.dump({"x_embed": synd, "fxtwitter": fx}, f, ensure_ascii=False, indent=1)

    def videos_of(t, origin):
        found = []
        for m in (t or {}).get("mediaDetails", []) or []:
            vi = m.get("video_info") or {}
            mp4 = [v for v in vi.get("variants", []) if v.get("content_type") == "video/mp4" and v.get("url")]
            if mp4:
                found.append({"origin": origin, "type": m.get("type"), "duration_ms": vi.get("duration_millis"),
                              "thumbnail": m.get("media_url_https"), "urls": [v["url"] for v in mp4]})
        return found

    vids = videos_of(synd, "post")
    if not vids and synd and synd.get("quoted_tweet"):
        vids = videos_of(synd["quoted_tweet"], "quoted post")
        if vids:
            warn("The post has no video of its own; the video comes from the post it quotes.")
    ft = (fx or {}).get("tweet") or {}
    if not vids:
        for v in ((ft.get("media") or {}).get("videos") or []):
            urls = [x.get("url") for x in (v.get("variants") or []) if (x.get("url") or "").split("?")[0].endswith(".mp4")]
            urls = urls or ([v["url"]] if v.get("url") else [])
            if urls:
                vids.append({"origin": "post (FxTwitter)", "type": v.get("type"),
                             "duration_ms": int((v.get("duration") or 0) * 1000), "thumbnail": v.get("thumbnail_url"),
                             "urls": urls})
    author = (synd or {}).get("user") or {}
    fa = ft.get("author") or {}
    q = (synd or {}).get("quoted_tweet") or {}
    text = (synd or {}).get("text") or ""
    if len(ft.get("text") or "") > len(text):
        text = ft["text"]
    website = fa.get("website")
    post = {
        "url": f"https://x.com/{user}/status/{tid}", "id": tid,
        "author": {"name": author.get("name") or fa.get("name"), "handle": author.get("screen_name") or fa.get("screen_name") or user,
                   "bio": fa.get("description"), "followers": fa.get("followers"), "location": fa.get("location"),
                   "website": website.get("url") if isinstance(website, dict) else website},
        "created_at": (synd or {}).get("created_at") or ft.get("created_at"), "text": text,
        "counts": {"likes": ft.get("likes", (synd or {}).get("favorite_count")), "reposts": ft.get("retweets"),
                   "replies": ft.get("replies", (synd or {}).get("conversation_count")), "views": ft.get("views"),
                   "bookmarks": ft.get("bookmarks")},
        "quoted": {"id": q.get("id_str"), "handle": (q.get("user") or {}).get("screen_name"), "text": q.get("text"),
                   "created_at": q.get("created_at")} if q else None,
        "videos_found": len(vids), "video": None, "replies_read": False,
    }
    if not vids:
        return post, None, None
    if video_index >= len(vids):
        warn(f"--video-index {video_index} is out of range; the post has {len(vids)} video(s). Using the first.")
        video_index = 0
    v = vids[video_index]
    if len(vids) > 1:
        warn(f"The post has {len(vids)} videos; using number {video_index} (pass --video-index for another).")
    if v.get("type") == "animated_gif":
        warn("The media is an animated GIF: it has no sound.")
    post["video"] = {"origin": v["origin"], "duration_ms": v["duration_ms"], "thumbnail": v["thumbnail"], "variants": v["urls"]}
    by_h = sorted(v["urls"], key=lambda u: resolution(u)[1])
    audio_url = next((u for u in by_h if resolution(u)[1] >= 360), by_h[-1])
    frames_url = next((u for u in reversed(by_h) if 0 < resolution(u)[1] <= 720), by_h[-1])
    return post, audio_url, frames_url


# ---------- yt-dlp ----------

def ytdlp_error(e):
    """The useful line of a failed yt-dlp run (for example 'Sign in to confirm your age')."""
    text = (getattr(e, "stderr", None) or getattr(e, "output", None) or str(e)).strip()
    lines = [l for l in text.splitlines() if "ERROR" in l] or text.splitlines() or [str(e)]
    return lines[-1].replace("ERROR: ", "").strip()[:300]


def ytdlp_info(url):
    ytdlp = need("yt-dlp", "Install it (brew install yt-dlp), or download the file and pass its path.")
    try:
        info = json.loads(run([ytdlp, "--ignore-config", "-J", "--no-playlist", "--no-warnings", url]).stdout)
    except subprocess.CalledProcessError as e:
        raise FetchError(f"yt-dlp could not read the video: {ytdlp_error(e)}")
    keep = ["id", "title", "uploader", "uploader_id", "channel", "channel_url", "upload_date", "timestamp",
            "duration", "description", "webpage_url", "view_count", "like_count", "comment_count", "tags",
            "categories", "chapters", "language", "age_limit", "availability", "live_status", "extractor_key"]
    page = {k: info.get(k) for k in keep if info.get(k) is not None}
    page["captions"] = sorted((info.get("subtitles") or {}).keys())
    auto = sorted((info.get("automatic_captions") or {}).keys())
    page["auto_captions_original"] = [k for k in auto if k.endswith("-orig")]
    page["auto_captions_count"] = len(auto)
    return ytdlp, page


def ytdlp_captions(ytdlp, url, out, page, lang):
    """Download one caption track as VTT. Return (file, track, human). The video's own language comes
    first: its human tracks (the exact tag, then the same language without its region), then the
    original-language machine track, then a machine track in that language (its tag, then the language
    without its region: machine tracks seldom carry one). A human track in another language is the last
    resort, with a warning: its text is a translation."""
    orig = page.get("auto_captions_original", [])
    want = lang if lang and lang != "auto" else (page.get("language") or "")
    if not want and orig:
        want = orig[0][:-len("-orig")]
    base = want.split("-")[0].lower()
    human = page.get("captions") or []
    own = [k for k in human if want and k.lower() == want.lower()]
    own += [k for k in human if base and k not in own and k.split("-")[0].lower() == base]
    other = [k for k in human if k not in own]
    plans = [("--write-subs", k, True) for k in own]
    plans += [("--write-auto-subs", k, False) for k in orig]
    if want:
        plans.append(("--write-auto-subs", want, False))
    if base and base != want.lower():
        plans.append(("--write-auto-subs", base, False))
    plans += [("--write-subs", k, True) for k in other[:1]]
    plans = plans or [("--write-auto-subs", "en", False)]
    last = ""
    for flag, track, is_human in plans:
        for old in glob.glob(os.path.join(out, "captions*.vtt")):
            os.remove(old)
        try:
            run([ytdlp, "--ignore-config", "--no-playlist", "--no-warnings", "--skip-download", flag, "--sub-langs", track,
                 "--sub-format", "vtt", "-o", os.path.join(out, "captions.%(ext)s"), url])
        except subprocess.CalledProcessError as e:
            last = ytdlp_error(e)
            continue
        files = sorted(glob.glob(os.path.join(out, "captions*.vtt")))
        if files:
            if want and track in other:
                warn(f"The captions are the human track '{track}', not the video's language ('{want}'): "
                     "the text is likely a translation, not the speaker's words.")
            return files[0], track, is_human
    raise FetchError("The platform gave no captions" + (f": {last}" if last else ".") +
                     " Ask the author for a local copy of the video.")


def ytdlp_download(ytdlp, url, out):
    """Download 720p or less into OUT/media.<ext>; return the file yt-dlp wrote. Old media.* files
    in a reused work folder are removed first, so that they can never stand in for this download."""
    for old in glob.glob(os.path.join(out, "media.*")):
        os.remove(old)
    r = run([ytdlp, "--ignore-config", "--no-playlist", "--no-warnings", "-f", "bv*[height<=720]+ba/b[height<=720]/b",
             "--merge-output-format", "mp4", "-o", os.path.join(out, "media.%(ext)s"),
             "--print", "after_move:filepath", "--no-simulate", url])
    printed = [l.strip() for l in r.stdout.splitlines() if l.strip()]
    path = printed[-1] if printed else None
    if not path or not os.path.isfile(path):
        files = glob.glob(os.path.join(out, "media.*"))
        path = files[0] if len(files) == 1 else None
    if not path:
        raise FetchError("yt-dlp finished but the downloaded file was not found.")
    return path


def vtt_segments(path, machine=None):
    """(start second, text) pairs from a VTT file. Machine captions roll: each cue repeats the
    previous cue's lines and adds new ones. In a machine track, a line is dropped only when its cue
    starts where the previous cue ended and that cue had the same line. Human tracks keep every line.
    MACHINE says which kind of track this is; the caller knows which one it downloaded."""
    with open(path, encoding="utf-8", errors="replace") as f:
        data = f.read()
    if machine is None:
        # Not told: word timings (<00:00:01.234>) or <c> tags suggest machine captions. Human tracks
        # can carry <c> style tags too, so a caller that knows the track type passes it.
        machine = bool(re.search(r"<\d{1,2}:\d{2}:\d{2}[.,]\d{3}>|<c>", data))
    segs, prev_lines, prev_end = [], set(), None
    for block in re.split(r"\n\s*\n", data):
        lines = block.strip().split("\n")
        ti = next((i for i, l in enumerate(lines) if "-->" in l), None)
        if ti is None:
            continue
        m = re.match(r"(?:(\d+):)?(\d+):(\d+)[.,](\d+)\s*-->\s*(?:(\d+):)?(\d+):(\d+)[.,](\d+)", lines[ti].strip())
        if not m:
            continue
        g = m.groups()
        start = int(g[0] or 0) * 3600 + int(g[1]) * 60 + int(g[2]) + int(g[3]) / 1000
        end = int(g[4] or 0) * 3600 + int(g[5]) * 60 + int(g[6]) + int(g[7]) / 1000
        texts = [html.unescape(re.sub(r"<[^>]+>", "", l)).strip() for l in lines[ti + 1:]]
        texts = [x for x in texts if x]
        rolling = machine and prev_end is not None and start - prev_end <= 1.0
        for txt in texts:
            if rolling and txt in prev_lines:
                continue
            segs.append((int(start), txt))
        prev_lines, prev_end = set(texts), end
    return segs


# ---------- whisper ----------

def find_whisper():
    for name in ("whisper-cli", "whisper-cpp"):
        p = shutil.which(name)
        if p:
            return p
    raise FetchError("whisper-cli is not installed. Install whisper.cpp (brew install whisper-cpp).")


def find_model(arg, name="small"):
    for c in (arg, os.environ.get("WHISPER_MODEL")):
        if c and os.path.isfile(os.path.expanduser(c)):
            return os.path.expanduser(c)
    for g in MODEL_GLOBS:
        hits = sorted(glob.glob(os.path.expanduser(g.format(m=name))))
        if hits:
            return hits[-1]
    raise FetchError("No ggml-small.bin model found. Download it once:\n"
                     "  mkdir -p ~/.cache/whisper && curl -L -o ~/.cache/whisper/ggml-small.bin "
                     "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin\n"
                     "or pass --model PATH (or set WHISPER_MODEL).")


def whisper(audio, prefix, lang, prompt, model, threads, extra=()):
    cmd = [find_whisper(), "-m", model, "-l", lang, "-t", str(threads), "-f", audio] + list(extra)
    if prompt:
        cmd += ["--prompt", prompt]
    if prefix:
        cmd += ["-osrt", "-otxt", "-of", prefix]
    return subprocess.run(cmd, capture_output=True, text=True)


def srt_segments(path):
    """(start, end, text) for each SRT cue, times in seconds."""
    segs = []
    with open(path, encoding="utf-8", errors="replace") as f:
        blocks = f.read().strip().split("\n\n")
    for b in blocks:
        lines = b.strip().split("\n")
        if len(lines) < 3:
            continue
        m = re.match(r"(\d+):(\d+):(\d+)[,.](\d+)\s*-->\s*(\d+):(\d+):(\d+)[,.](\d+)", lines[1])
        if not m:
            continue
        g = [int(x) for x in m.groups()]
        start = g[0] * 3600 + g[1] * 60 + g[2] + g[3] / 1000
        end = g[4] * 3600 + g[5] * 60 + g[6] + g[7] / 1000
        segs.append((start, end, " ".join(x.strip() for x in lines[2:]).strip()))
    return segs


# Lines whisper is known to invent over music or silence (lowercase fragments).
PHANTOMS = ["amara.org", "subtítulos realizados por", "subtitulos realizados por", "subtítulos por la comunidad",
            "thanks for watching", "thank you for watching", "subtitles by", "transcribed by",
            "gracias por ver", "¡suscríbete", "suscríbete al canal", "sous-titres réalisés"]


def transcript_checks(segs):
    """Warnings about the transcript: likely dropped speech, invented lines, repeat loops."""
    out = []
    for start, end, text in segs:
        span, words = end - start, len(text.split())
        if span >= 10 and words / span < 1.0:
            out.append(f"Possible dropped speech at {stamp(start)}–{stamp(end)} ({words} words in {span:.0f} s): "
                       "re-transcribe it with --segment.")
        low = text.lower()
        if any(p in low for p in PHANTOMS):
            out.append(f"Possible invented line at {stamp(start)}: «{text[:80]}». Check it against the audio.")
    run_len, prev = 1, None
    for start, _, text in segs:
        run_len = run_len + 1 if text and text == prev else 1
        if run_len == 3:
            out.append(f"Repeated line from about {stamp(start)}: «{text[:60]}» (a whisper loop?).")
        prev = text
    return out


def write_blocks(segs, path, every=45):
    blocks, cur = [], None
    for t, txt in segs:
        if cur is None or t - cur[0] >= every:
            if cur:
                blocks.append(cur)
            cur = [t, [txt]]
        else:
            cur[1].append(txt)
    if cur:
        blocks.append(cur)
    with open(path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(f"[{stamp(t)}] " + re.sub(r"\s+", " ", " ".join(x)).strip() for t, x in blocks) + "\n")
    return len(blocks)


# ---------- frames ----------

def scene_times(src, threshold=0.3):
    """Times of shot changes and new slides, from a quick low-resolution decode."""
    r = subprocess.run(["ffmpeg", "-nostdin", "-hide_banner", "-i", src, "-an", "-vf",
                        f"scale=320:-2,select='gt(scene,{threshold})',showinfo", "-f", "null", "-"],
                       capture_output=True, text=True)
    return [float(x) for x in re.findall(r"pts_time:([\d.]+)", r.stderr)]


def frame_plan(dur, n, scenes, cap):
    """n evenly spaced times plus the scene changes, at most cap in all."""
    n = max(0, min(n, cap))
    edge = min(2.0, dur / 10)
    even = [round(edge + (i + 0.5) * (dur - 2 * edge) / n, 2) for i in range(n)] if dur > 0 and n > 0 else []
    picked = []
    for cut in sorted(scenes):
        t = round(min(cut + 0.5, max(dur - 0.1, 0)), 2)  # half a second into the new shot
        # Skip only when a frame already shows this shot: one that falls just after the cut.
        # A frame just before the cut shows the previous shot (a 2026-10-12 test lost a date card that way).
        if any(cut <= x <= cut + 2.0 for x in even) or any(abs(t - x) < 1.0 for x in picked):
            continue
        picked.append(t)
    room = max(cap - len(even), 0)
    if len(picked) > room:
        step = len(picked) / room if room else 0
        picked = [picked[int(i * step)] for i in range(room)] if room else []
    return sorted([(t, "even") for t in even] + [(t, "scene") for t in picked])


def frames(src, plan, width, height, out):
    fdir, sdir = os.path.join(out, "frames"), os.path.join(out, "sheets")
    for d in (fdir, sdir):
        os.makedirs(d, exist_ok=True)  # clean_out emptied them at the start; the input file may be inside
    portrait = height > width
    W, H = (360, 640) if portrait else (640, 360)
    cols, rows = (4, 2) if portrait else (2, 4)
    font = next((f for f in FONTS if os.path.isfile(f)), None)
    if font and "drawtext" not in run(["ffmpeg", "-hide_banner", "-filters"]).stdout:
        font = None  # this ffmpeg has no drawtext filter: the times live in the manifest only
    base = f"scale={W}:{H}:force_original_aspect_ratio=decrease,pad={W}:{H}:(ow-iw)/2:(oh-ih)/2:color=black"
    made, r = [], None
    for i, (t, why) in enumerate(plan, 1):
        dst = os.path.join(fdir, f"f-{i:03d}.jpg")
        vf = base
        if font:
            label = stamp(t).replace(":", r"\:")
            vf += (f",drawtext=fontfile={font}:text='{label}':x=10:y=10:fontsize=26:fontcolor=white"
                   ":box=1:boxcolor=black@0.6:boxborderw=6")
        ok = False
        for attempt_vf in ([vf, base] if font else [base]):
            r = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", str(t), "-i", src,
                                "-frames:v", "1", "-q:v", "3", "-vf", attempt_vf, dst], capture_output=True, text=True)
            if r.returncode == 0 and os.path.isfile(dst):
                ok = True
                break
        if ok:
            made.append({"t": t, "at": stamp(t), "why": why, "file": f"frames/f-{i:03d}.jpg"})
        else:
            warn(f"Frame at {stamp(t)} failed: {(r.stderr if r else '').strip()[:160]}")
    if not made:
        return made, []
    blank = os.path.join(fdir, "blank.jpg")
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i",
                    f"color=c=black:s={W}x{H}", "-frames:v", "1", blank], capture_output=True)
    sheets, per = [], cols * rows
    for s in range(0, len(made), per):
        group = [os.path.join(out, m["file"]) for m in made[s:s + per]]
        group += [blank] * (per - len(group))
        tmp = os.path.join(sdir, f"_list-{s // per + 1}.txt")
        with open(tmp, "w") as f:
            f.write("".join("file '" + p.replace("'", "'\\''") + "'\n" for p in group))
        name = f"sheets/sheet-{s // per + 1}.jpg"
        r = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", tmp,
                            "-vf", f"tile={cols}x{rows}:padding=4:margin=4", "-frames:v", "1", "-q:v", "3",
                            os.path.join(out, name)], capture_output=True, text=True)
        os.remove(tmp)
        if r.returncode == 0:
            sheets.append({"file": name, "layout": f"{cols} columns x {rows} rows, read left to right, top to bottom",
                           "times": [m["at"] for m in made[s:s + per]]})
        else:
            warn(f"Contact sheet {s // per + 1} failed: {r.stderr.strip()[:160]}")
    if os.path.isfile(blank):
        os.remove(blank)
    return made, sheets


# ---------- main ----------

def same_file(a, b):
    """True when A and B are one file, however each path is written (/tmp and /private/tmp, links)."""
    try:
        return os.path.samefile(a, b)
    except OSError:
        return False


def clean_out(out, keep=()):
    """Remove what an earlier run left in a reused work folder, so that old frames, audio or
    text can never pass for this source's. A file in keep (the source file itself) stays, wherever
    it is in the folder and however its path is written. So does a folder link that a kept file is
    under: the input path can run through it (out/frames/link/clip.mp4)."""
    keep = [k for k in keep if os.path.isfile(k)]
    real_keep = [os.path.realpath(k) for k in keep]

    def kept(p):
        return any(same_file(p, k) for k in keep)

    def holds_kept(link):
        target = os.path.realpath(link)
        return any(os.path.commonpath([target, k]) == target for k in real_keep)

    names = [os.path.join(out, n) for n in ("manifest.json", "source.json", "audio.wav", "transcript.srt",
                                             "transcript.txt", "blocks.md", "whisper.log")]
    for pattern in ("captions*.vtt", "segment-*.wav", "hd-*.jpg"):
        names += glob.glob(os.path.join(out, pattern))
    for p in names:
        if os.path.isfile(p) and not kept(p):
            os.remove(p)
    for sub in ("frames", "sheets"):
        top = os.path.join(out, sub)
        if os.path.islink(top) or not os.path.isdir(top):
            continue
        for root, dirs, files in os.walk(top, topdown=False):
            for n in files:
                if not kept(os.path.join(root, n)):
                    os.remove(os.path.join(root, n))
            for n in dirs:
                p = os.path.join(root, n)
                if os.path.islink(p):
                    if not holds_kept(p):
                        os.remove(p)
                    continue
                try:
                    os.rmdir(p)
                except OSError:
                    pass  # it holds a kept file
        try:
            os.rmdir(top)
        except OSError:
            pass


def slug_for(source):
    m = X_RE.match(source)
    if m:
        return f"x-{m.group(1).lower()}-{m.group(2)}"
    if os.path.exists(os.path.expanduser(source)):
        return re.sub(r"[^a-z0-9]+", "-", os.path.splitext(os.path.basename(source))[0].lower()).strip("-")[:50] or "local"
    y = re.search(r"(?:v=|youtu\.be/|shorts/)([\w-]{6,})", source)
    if y:
        return f"yt-{y.group(1).lower()}"
    return re.sub(r"[^a-z0-9]+", "-", re.sub(r"^https?://", "", source.lower())).strip("-")[:50]


def kind_of(source):
    if X_RE.match(source):
        return "x"
    if re.match(r"^https?://", source, re.I):
        return "yt-dlp"
    return "local"


def info_only(source, a):
    """--info: describe the source without downloading it."""
    k = kind_of(source)
    if k == "x":
        m = X_RE.match(source)
        post, _, _ = x_lookup(m.group(1), m.group(2), None, a.video_index)
        v = post.get("video") or {}
        return {"kind": "x", "duration_s": round((v.get("duration_ms") or 0) / 1000, 1), "author": post["author"],
                "created_at": post["created_at"], "text": post["text"], "quoted": post["quoted"],
                "videos_found": post["videos_found"], "video_origin": v.get("origin"), "counts": post["counts"],
                "warnings": warnings}
    if k == "yt-dlp":
        _, page = ytdlp_info(source)
        desc = page.pop("description", "") or ""
        page["description_start"] = desc[:600]
        page["kind"] = "yt-dlp"
        page["duration_s"] = page.pop("duration", None)
        page["needs_sign_in"] = bool(page.get("age_limit")) or page.get("availability") not in (None, "public", "unlisted")
        return page
    p = os.path.abspath(os.path.expanduser(source))
    if not os.path.isfile(p):
        raise FetchError(f"Not a file: {p}")
    return {"kind": "local", "path": p, **ffprobe(p)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", nargs="?", help="X post URL, any yt-dlp URL, or a local video or audio file")
    ap.add_argument("--source-file", help="read SOURCE from this file (keeps an untrusted URL out of the shell)")
    ap.add_argument("--info", action="store_true", help="describe the source and download nothing")
    ap.add_argument("--out", help="work folder (default /tmp/video-to-card/<slug>)")
    ap.add_argument("--lang", default="auto", help="spoken language: auto (default), en, es, ...")
    ap.add_argument("--prompt", default="", help="names and terms that help whisper spell them right")
    ap.add_argument("--frames", type=int, default=16, help="number of evenly spaced frames (default 16, 0 = none)")
    ap.add_argument("--max-frames", type=int, default=48, help="cap on all frames, scene changes included (default 48)")
    ap.add_argument("--no-scenes", action="store_true", help="skip the frames taken at scene changes")
    ap.add_argument("--captions", action="store_true", help="use the platform's captions instead of whisper (yt-dlp sources)")
    ap.add_argument("--model", help="path to a ggml model (default: ggml-small.bin, found automatically)")
    ap.add_argument("--threads", type=int, default=min(os.cpu_count() or 4, 12))
    ap.add_argument("--video-index", type=int, default=0, help="which video of an X post with several (default 0)")
    ap.add_argument("--no-transcribe", action="store_true", help="fetch and sample frames only")
    ap.add_argument("--segment", help="START:SECONDS — re-transcribe part of OUT/audio.wav and print the text")
    a = ap.parse_args()

    try:
        need("ffmpeg", "Install it (brew install ffmpeg).")
        need("ffprobe", "Install ffmpeg (brew install ffmpeg).")
    except FetchError as e:
        sys.exit(str(e))

    if a.segment:
        if not a.out:
            sys.exit("--segment needs --out (the folder of an earlier run).")
        audio = os.path.join(a.out, "audio.wav")
        if not os.path.isfile(audio):
            sys.exit(f"No audio.wav in {a.out}.")
        try:
            start, secs = (float(x) for x in a.segment.split(":"))
        except ValueError:
            sys.exit("--segment takes START:SECONDS, for example 475:18.")
        clip = os.path.join(a.out, f"segment-{int(start)}-{int(secs)}.wav")
        run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-ss", str(start), "-t", str(secs), "-i", audio,
             "-ac", "1", "-ar", "16000", clip])
        try:
            r = whisper(clip, None, a.lang, a.prompt, find_model(a.model), a.threads, extra=["-nt"])
        except FetchError as e:
            sys.exit(str(e))
        finally:
            os.remove(clip)
        if r.returncode != 0:
            sys.exit(r.stderr.strip()[-400:])
        print(re.sub(r"\n\s*\n", "\n", r.stdout).strip())
        return

    source = a.source
    if a.source_file:
        with open(os.path.expanduser(a.source_file), encoding="utf-8") as f:
            source = f.read().strip()
    if not source:
        ap.error("SOURCE (or --source-file) is required")

    if a.info:
        try:
            print(json.dumps(info_only(source, a), ensure_ascii=False, indent=1))
        except FetchError as e:
            sys.exit(str(e))
        return

    out = os.path.abspath(os.path.expanduser(a.out or os.path.join("/tmp/video-to-card", slug_for(source))))
    os.makedirs(out, exist_ok=True)
    clean_out(out, keep=[os.path.expanduser(source)] if kind_of(source) == "local" else [])
    started = time.time()
    manifest = {"tool": "video-to-card/scripts/fetch_video.py",
                "fetched": datetime.datetime.now().astimezone().isoformat(timespec="seconds"),
                "out": out, "source": {"kind": kind_of(source), "input": source}, "media": None, "transcript": None,
                "frames": [], "sheets": [], "warnings": warnings, "error": None}

    def save():
        manifest["elapsed_s"] = round(time.time() - started, 1)
        with open(os.path.join(out, "manifest.json"), "w") as f:
            json.dump(manifest, f, ensure_ascii=False, indent=1)

    def fail(msg):
        manifest["error"] = msg
        save()
        sys.exit(f"{msg}\n(manifest: {os.path.join(out, 'manifest.json')})")

    try:
        manifest["tools"] = {"ffmpeg": run(["ffmpeg", "-version"]).stdout.split("\n")[0]}
        media = frame_src = None
        captions_file = None
        k = kind_of(source)
        if k == "x":
            m = X_RE.match(source)
            post, audio_url, frame_src = x_lookup(m.group(1), m.group(2), out, a.video_index)
            manifest["post"] = post
            manifest["source"]["id"] = m.group(2)
            if not audio_url:
                fail("No video found in this post or in the post it quotes.")
            media = os.path.join(out, "media.mp4")
            log(f"Downloading {audio_url}")
            download(audio_url, media)
        elif k == "yt-dlp":
            ytdlp, page = ytdlp_info(source)
            manifest["page"] = page
            manifest["source"].update({"id": page.get("id"), "extractor": page.get("extractor_key")})
            with open(os.path.join(out, "source.json"), "w") as f:
                json.dump(page, f, ensure_ascii=False, indent=1)
            if a.captions:
                captions_file, track, is_human = ytdlp_captions(ytdlp, source, out, page, a.lang)
            else:
                log("Downloading the video (720p or less) with yt-dlp")
                try:
                    media = frame_src = ytdlp_download(ytdlp, source, out)
                except subprocess.CalledProcessError as e:
                    warn(f"The media download failed: {ytdlp_error(e)}. Trying the platform's captions.")
                    captions_file, track, is_human = ytdlp_captions(ytdlp, source, out, page, a.lang)
        else:
            p = os.path.abspath(os.path.expanduser(source))
            if not os.path.isfile(p):
                fail(f"Not a file: {p}")
            media = frame_src = p
            manifest["source"]["path"] = p

        if captions_file:
            segs = vtt_segments(captions_file, machine=not is_human)
            with open(os.path.join(out, "transcript.txt"), "w", encoding="utf-8") as f:
                f.write("\n".join(t for _, t in segs) + "\n")
            nblocks = write_blocks(segs, os.path.join(out, "blocks.md"))
            manifest["transcript"] = {"source": "platform captions", "file": os.path.basename(captions_file),
                                      "track": track, "human_track": is_human,
                                      "words": sum(len(t.split()) for _, t in segs), "segments": len(segs),
                                      "blocks": nblocks, "files": ["transcript.txt", "blocks.md", os.path.basename(captions_file)]}
            manifest["media"] = {"duration_s": manifest.get("page", {}).get("duration")}
            warn("No media was downloaded: there are no frames, and the text is the platform's captions, not whisper.")
            save()
            print(json.dumps({"out": out, "transcript": "captions", "words": manifest["transcript"]["words"],
                              "warnings": warnings}, ensure_ascii=False))
            return

        if not media:
            fail("yt-dlp finished but no media file was found.")
        info = ffprobe(media)
        if frame_src != media:
            try:
                remote = ffprobe(frame_src)
                info.update({k2: remote[k2] for k2 in ("width", "height") if k2 in remote})
            except subprocess.CalledProcessError:
                warn("Could not read the high-resolution file; frames come from the downloaded file.")
                frame_src = media
        dur = info["duration_s"]
        log(f"Media: {dur:.0f} s, audio={info['has_audio']}, video={info['has_video']} "
            f"{info.get('width', '')}x{info.get('height', '')}")
        manifest["media"] = {"file": os.path.relpath(media, out) if media.startswith(out) else media,
                             "frames_from": frame_src, **info}

        if info["has_audio"] and not a.no_transcribe:
            audio = os.path.join(out, "audio.wav")
            if same_file(media, audio):
                fail(f"The input file is this run's audio.wav ({audio}): transcribing would write over it. "
                     "Pass another --out, or rename the file.")
            run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-i", media, "-vn", "-ac", "1", "-ar", "16000",
                 "-c:a", "pcm_s16le", audio])
            model = find_model(a.model)
            log(f"Transcribing {dur / 60:.1f} min of audio with {os.path.basename(model)} "
                f"({a.threads} threads; about {max(1, round(dur / 300))} min on a recent Apple-silicon Mac)")
            t0 = time.time()
            r = whisper(audio, os.path.join(out, "transcript"), a.lang, a.prompt, model, a.threads)
            with open(os.path.join(out, "whisper.log"), "w") as f:
                f.write(r.stdout + "\n--- stderr ---\n" + r.stderr)
            if r.returncode != 0:
                fail("whisper failed; see " + os.path.join(out, "whisper.log"))
            detected = re.search(r"auto-detected language: (\w+) \(p = ([\d.]+)\)", r.stderr)
            segs = srt_segments(os.path.join(out, "transcript.srt"))
            nblocks = write_blocks([(st, tx) for st, _, tx in segs], os.path.join(out, "blocks.md"))
            for w in transcript_checks(segs):
                warn(w)
            with open(os.path.join(out, "transcript.txt"), encoding="utf-8", errors="replace") as f:
                words = len(f.read().split())
            manifest["transcript"] = {"source": "whisper.cpp", "model": os.path.basename(model), "model_path": model,
                                      "lang": a.lang, "detected_language": detected.group(1) if detected else None,
                                      "detected_p": float(detected.group(2)) if detected else None,
                                      "prompt": a.prompt, "words": words, "segments": len(segs), "blocks": nblocks,
                                      "seconds": round(time.time() - t0, 1), "whisper": find_whisper(),
                                      "files": ["transcript.srt", "transcript.txt", "blocks.md", "whisper.log"]}
            if words < max(20, dur / 10):
                warn(f"Only {words} words for {dur:.0f} s: music, silence, or the wrong --lang?")
        elif not info["has_audio"]:
            warn("The media has no audio track: nothing to transcribe.")

        if info["has_video"] and (a.frames > 0 or not a.no_scenes) and a.max_frames > 0:
            scenes = [] if a.no_scenes else scene_times(media)
            plan = frame_plan(dur, a.frames, scenes, a.max_frames)
            manifest["scene_changes"] = len(scenes)
            if len(scenes) > a.max_frames:
                warn(f"{len(scenes)} scene changes; frames keep {a.max_frames} in all. Raise --max-frames for a slide-heavy video.")
            made, sheets = frames(frame_src, plan, info.get("width", 16), info.get("height", 9), out)
            manifest["frames"], manifest["sheets"] = made, sheets
    except FetchError as e:
        fail(str(e))
    except subprocess.CalledProcessError as e:
        fail(f"{os.path.basename(str(e.cmd[0]))} failed: {(e.stderr or '').strip()[-300:]}")

    save()
    t = manifest["transcript"]
    print(json.dumps({"out": out, "duration_s": manifest["media"]["duration_s"], "words": t["words"] if t else 0,
                      "language": t.get("detected_language") if t else None, "sheets": manifest["sheets"],
                      "warnings": warnings}, ensure_ascii=False))


if __name__ == "__main__":
    main()
