#!/usr/bin/env python3
"""Tests for fetch_video.py. Run: python3 skills/video-to-card/scripts/fetch_video.test.py

Offline: a fake yt-dlp and two tiny ffmpeg-made files stand in for the network.
Needs ffmpeg and ffprobe. Prints one line per check and exits 1 on any failure.
"""
import importlib.util
import json
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "fetch_video.py")
spec = importlib.util.spec_from_file_location("fetch_video", SCRIPT)
fv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fv)

failed = 0


def check(name, ok, detail=""):
    global failed
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f" — {detail}"))
    failed += 0 if ok else 1


def test_captions_keep_real_repeats():
    # Review round 1, finding 1: separate cues that say the same thing are real speech.
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.vtt")
        with open(p, "w") as f:
            f.write("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nYes.\n\n"
                    "00:01:01.000 --> 00:01:02.000\nNo.\n\n"
                    "00:02:01.000 --> 00:02:02.000\nYes.\n")
        segs = fv.vtt_segments(p)
        check("captions keep a line said again a minute later", [t for _, t in segs] == ["Yes.", "No.", "Yes."], segs)


def test_captions_drop_rolling_repeats():
    # YouTube machine captions repeat the previous line in the next cue, seconds later.
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.vtt")
        with open(p, "w") as f:
            f.write("WEBVTT\n\n00:00:00.000 --> 00:00:02.000\nhola a todos\n\n"
                    "00:00:02.000 --> 00:00:02.010\nhola a todos\n\n"
                    "00:00:02.010 --> 00:00:04.000\nhola a todos\nhoy hablamos<00:00:03.000><c> de facturas</c>\n")
        segs = fv.vtt_segments(p)
        check("captions drop the rolling repeat of the previous line",
              [t for _, t in segs] == ["hola a todos", "hoy hablamos de facturas"], segs)


def test_frame_cap_limits_all_frames():
    # Review round 1, finding 3: --max-frames caps the even frames too.
    plan = fv.frame_plan(100.0, 16, [], 4)
    check("--max-frames 4 gives at most 4 frames", len(plan) <= 4, f"{len(plan)} frames")
    plan = fv.frame_plan(100.0, 4, [10.0, 50.0, 80.0], 6)
    check("scene frames fill the room left under the cap", len(plan) == 6, plan)


def test_stale_media_is_not_used():
    # Review round 1, finding 2: an old media.* file in a reused folder must not win.
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "out")
        os.makedirs(out)
        new = os.path.join(d, "new.mp4")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=2:s=160x120",
                        "-f", "lavfi", "-i", "sine=d=2", "-shortest", "-c:v", "libx264", "-c:a", "aac", new], check=True)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=5:s=160x120",
                        "-f", "lavfi", "-i", "sine=d=5", "-shortest", "-c:v", "libx264", "-c:a", "aac",
                        os.path.join(out, "media.mkv")], check=True)
        bin_dir = os.path.join(d, "bin")
        os.makedirs(bin_dir)
        fake = os.path.join(bin_dir, "yt-dlp")
        with open(fake, "w") as f:
            f.write(f"""#!/usr/bin/env python3
import json, shutil, sys
a = sys.argv[1:]
if "-J" in a:
    print(json.dumps({{"id": "abc123", "title": "t", "duration": 2, "extractor_key": "Fake"}}))
    sys.exit(0)
o = a[a.index("-o") + 1]
path = o.replace("%(ext)s", "mp4")
shutil.copy({new!r}, path)
if "--print" in a:
    print(path)
""")
        os.chmod(fake, 0o755)
        env = dict(os.environ, PATH=bin_dir + os.pathsep + os.environ.get("PATH", ""))
        r = subprocess.run([sys.executable, SCRIPT, "https://example.com/watch?v=abc123", "--out", out,
                            "--no-transcribe", "--frames", "0", "--no-scenes"], capture_output=True, text=True, env=env)
        try:
            m = json.load(open(os.path.join(out, "manifest.json")))
        except (OSError, ValueError) as e:
            check("a reused folder uses the new download, not an old media file", False, f"no manifest: {e}; {r.stderr[-300:]}")
            return
        media = m.get("media") or {}
        check("a reused folder uses the new download, not an old media file",
              media.get("file") == "media.mp4" and round(media.get("duration_s") or 0) == 2,
              f"file={media.get('file')} duration={media.get('duration_s')} exit={r.returncode} {r.stderr[-200:]}")


def test_human_captions_keep_adjacent_repeats():
    # Review round 2, finding 1: human captions do not roll, so an adjacent repeat is real speech.
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.vtt")
        with open(p, "w") as f:
            f.write("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nYes.\n\n"
                    "00:00:02.500 --> 00:00:03.500\nYes.\n")
        segs = fv.vtt_segments(p)
        check("human captions keep the same line in two adjacent cues", [t for _, t in segs] == ["Yes.", "Yes."], segs)


def test_reused_folder_drops_old_artifacts():
    # Review round 2, finding 2: a new run must not leave another run's frames, sheets or audio.
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "out")
        for sub in ("frames", "sheets"):
            os.makedirs(os.path.join(out, sub))
        stale = ["frames/f-001.jpg", "sheets/sheet-1.jpg", "audio.wav", "blocks.md", "transcript.srt",
                 "transcript.txt", "whisper.log", "captions.en.vtt", "source.json"]
        for rel in stale:
            with open(os.path.join(out, rel), "w") as f:
                f.write("old run")
        clip = os.path.join(d, "clip.mp4")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=2:s=160x120",
                        "-f", "lavfi", "-i", "sine=d=2", "-shortest", "-c:v", "libx264", "-c:a", "aac", clip], check=True)
        r = subprocess.run([sys.executable, SCRIPT, clip, "--out", out, "--no-transcribe", "--frames", "0", "--no-scenes"],
                           capture_output=True, text=True)
        left = [rel for rel in stale if os.path.exists(os.path.join(out, rel))]
        check("a new run removes the old run's generated files", not left and r.returncode == 0,
              f"left: {left}; exit={r.returncode} {r.stderr[-200:]}")


def make_audio(path, secs=2):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", f"sine=d={secs}", path],
                   check=True)


def test_cleanup_keeps_the_input_file():
    # Review round 3, finding 1: the clean-up compared paths as written, and on a Mac /tmp and /private/tmp
    # are one folder. It also removed the picture folders whole, with an input file inside them.
    with tempfile.TemporaryDirectory() as d:
        real = os.path.join(d, "real")
        os.makedirs(os.path.join(real, "out", "frames"))
        link = os.path.join(d, "link")
        os.symlink(real, link)
        cases = [("input named like the run's sound track, work folder through a link",
                  os.path.join(real, "out", "audio.wav"), os.path.join(link, "out")),
                 ("input named like the run's sound track, input through a link",
                  os.path.join(link, "out", "audio.wav"), os.path.join(real, "out")),
                 ("input inside the frames folder", os.path.join(real, "out", "frames", "clip.wav"),
                  os.path.join(real, "out"))]
        for name, src, out in cases:
            make_audio(os.path.realpath(src))
            r = subprocess.run([sys.executable, SCRIPT, src, "--out", out, "--no-transcribe", "--frames", "0",
                                "--no-scenes"], capture_output=True, text=True)
            check(f"the clean-up keeps the input file: {name}", os.path.isfile(src) and r.returncode == 0,
                  f"exists={os.path.isfile(src)} exit={r.returncode} {r.stderr[-200:]}")
            if os.path.isfile(src):
                os.remove(src)
        # A video inside the frames folder survives the frames step too, and its frames are made.
        src = os.path.join(real, "out", "frames", "clip.mp4")
        os.makedirs(os.path.dirname(src), exist_ok=True)
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=2:s=160x120",
                        "-f", "lavfi", "-i", "sine=d=2", "-shortest", "-c:v", "libx264", "-c:a", "aac", src], check=True)
        r = subprocess.run([sys.executable, SCRIPT, src, "--out", os.path.join(link, "out"), "--no-transcribe",
                            "--frames", "2", "--no-scenes"], capture_output=True, text=True)
        fdir = os.path.join(real, "out", "frames")
        made = sorted(n for n in os.listdir(fdir) if n.startswith("f-")) if os.path.isdir(fdir) else []
        check("a video inside the frames folder survives the frames step", os.path.isfile(src) and len(made) == 2
              and r.returncode == 0, f"exists={os.path.isfile(src)} frames={made} exit={r.returncode} {r.stderr[-200:]}")
        if os.path.isfile(src):
            os.remove(src)
        # With transcription on, the run would write its sound track over that input: it must refuse first.
        src = os.path.join(link, "out", "audio.wav")
        make_audio(os.path.realpath(src))
        with open(src, "rb") as f:
            before = f.read()
        r = subprocess.run([sys.executable, SCRIPT, src, "--out", os.path.join(real, "out"), "--frames", "0",
                            "--no-scenes"], capture_output=True, text=True)
        after = open(src, "rb").read() if os.path.isfile(src) else b""
        check("a run refuses to write its sound track over the input file",
              r.returncode != 0 and after == before and "audio.wav" in r.stderr,
              f"same={after == before} exit={r.returncode} {r.stderr[-200:]}")


def test_cleanup_keeps_a_link_the_input_runs_through():
    # Review round 2 of #41 (Claude): the clean-up removed every folder link under frames/ or sheets/, also one
    # that the input path runs through (out/frames/link/clip.wav), so the run stopped with "Not a file".
    with tempfile.TemporaryDirectory() as d:
        out = os.path.join(d, "out")
        away, other = os.path.join(d, "away"), os.path.join(d, "other")
        make_audio(os.path.join(away, "clip.wav"))
        os.makedirs(other)
        os.makedirs(os.path.join(out, "frames"))
        os.makedirs(os.path.join(out, "sheets"))
        link, stale = os.path.join(out, "frames", "link"), os.path.join(out, "sheets", "old")
        os.symlink(away, link)
        os.symlink(other, stale)
        src = os.path.join(link, "clip.wav")
        r = subprocess.run([sys.executable, SCRIPT, src, "--out", out, "--no-transcribe", "--frames", "0", "--no-scenes"],
                           capture_output=True, text=True)
        check("the clean-up keeps a folder link that the input path runs through",
              os.path.islink(link) and os.path.isfile(src) and r.returncode == 0,
              f"link={os.path.islink(link)} exists={os.path.isfile(src)} exit={r.returncode} {r.stderr[-200:]}")
        check("...and still removes a folder link that holds no kept file",
              not os.path.lexists(stale) and os.path.isdir(other), f"stale link left={os.path.lexists(stale)}")


FAKE_YTDLP = r'''#!/usr/bin/env python3
import json, os, shutil, sys
a = sys.argv[1:]
here = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(here, "calls.log"), "a") as f:
    f.write(json.dumps(a) + "\n")
cfg = json.load(open(os.path.join(here, "fake.json")))
if "-J" in a:
    print(json.dumps(cfg["info"]))
    sys.exit(0)
o = a[a.index("-o") + 1]
if "--skip-download" in a:
    track = a[a.index("--sub-langs") + 1]
    if track in cfg.get("vtt", {}):
        with open(o.replace("%(ext)s", track + ".vtt"), "w") as f:
            f.write(cfg["vtt"][track])
    sys.exit(0)
path = o.replace("%(ext)s", "mp4")
shutil.copy(cfg["media"], path)
if "--print" in a:
    print(path)
'''


def fake_ytdlp(d, cfg):
    """A fake yt-dlp in D/bin that logs each call's arguments to D/bin/calls.log."""
    bin_dir = os.path.join(d, "bin")
    os.makedirs(bin_dir, exist_ok=True)
    fake = os.path.join(bin_dir, "yt-dlp")
    with open(fake, "w") as f:
        f.write(FAKE_YTDLP)
    os.chmod(fake, 0o755)
    with open(os.path.join(bin_dir, "fake.json"), "w") as f:
        json.dump(cfg, f)
    return fake


STYLED_REPEAT = ("WEBVTT\n\n00:00:01.000 --> 00:00:02.000\n<c>Yes.</c>\n\n"
                 "00:00:02.000 --> 00:00:03.000\n<c>Yes.</c>\n")


def test_ytdlp_ignores_its_settings_files():
    # Review round 3, finding 2: a yt-dlp settings file can turn on browser cookies, so every call ignores it.
    # Finding 4 too: a human track with style tags keeps a line said twice in adjacent cues.
    with tempfile.TemporaryDirectory() as d:
        clip = os.path.join(d, "clip.mp4")
        subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=d=2:s=160x120",
                        "-f", "lavfi", "-i", "sine=d=2", "-shortest", "-c:v", "libx264", "-c:a", "aac", clip], check=True)
        fake = fake_ytdlp(d, {"info": {"id": "abc123", "title": "t", "duration": 3, "extractor_key": "Fake",
                                       "language": "en", "subtitles": {"en": []}},
                              "vtt": {"en": STYLED_REPEAT}, "media": clip})
        env = dict(os.environ, PATH=os.path.dirname(fake) + os.pathsep + os.environ.get("PATH", ""))
        url = "https://example.com/watch?v=abc123"
        r1 = subprocess.run([sys.executable, SCRIPT, url, "--out", os.path.join(d, "c"), "--captions"],
                            capture_output=True, text=True, env=env)
        r2 = subprocess.run([sys.executable, SCRIPT, url, "--out", os.path.join(d, "m"), "--no-transcribe",
                             "--frames", "0", "--no-scenes"], capture_output=True, text=True, env=env)
        calls = [json.loads(l) for l in open(os.path.join(os.path.dirname(fake), "calls.log"))]
        kinds = sorted({"info" if "-J" in c else "captions" if "--skip-download" in c else "download" for c in calls})
        check("every yt-dlp call ignores yt-dlp's settings files",
              kinds == ["captions", "download", "info"] and all("--ignore-config" in c for c in calls)
              and r1.returncode == 0 and r2.returncode == 0,
              f"calls={[c[:3] for c in calls]} exits={r1.returncode},{r2.returncode} {r1.stderr[-150:]} {r2.stderr[-150:]}")
        text = open(os.path.join(d, "c", "transcript.txt")).read().split() if r1.returncode == 0 else []
        check("a human track with style tags keeps the same line in two adjacent cues", text == ["Yes.", "Yes."], text)


def test_captions_language_choice():
    # Review round 3, finding 3: the video's own language first (the exact tag, then the language without
    # its region; human before machine), and another language only as a last resort, with a warning.
    cases = [("pt-BR video, human en and pt-BR", {"language": "pt-BR", "captions": ["en", "pt-BR"]},
              ["en", "pt-BR"], ("pt-BR", True), False),
             ("es-419 video, human en and es", {"language": "es-419", "captions": ["en", "es"]},
              ["en", "es"], ("es", True), False),
             ("pt video, a machine original track and human en",
              {"language": "pt", "captions": ["en"], "auto_captions_original": ["pt-orig"]},
              ["en", "pt-orig"], ("pt-orig", False), False),
             ("pt video, human en only", {"language": "pt", "captions": ["en"]}, ["en"], ("en", True), True),
             # Round 1 of #41 (Claude): machine tracks carry no region, and every own-language human track is tried.
             ("pt-BR video, no -orig track, machine pt and human en", {"language": "pt-BR", "captions": ["en"]},
              ["en", "pt"], ("pt", False), False),
             ("es-419 video, its es-419 track fails, human es", {"language": "es-419", "captions": ["es", "es-419"]},
              ["es"], ("es", True), False)]
    for name, page, avail, want, warned in cases:
        with tempfile.TemporaryDirectory() as d:
            fake = fake_ytdlp(d, {"info": {}, "vtt": {k: "WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhola\n" for k in avail}})
            out = os.path.join(d, "out")
            os.makedirs(out)
            del fv.warnings[:]
            try:
                _, track, human = fv.ytdlp_captions(fake, "https://example.com/v", out, page, "auto")
            except Exception as e:
                check(f"captions language: {name}", False, repr(e))
                continue
            said = any("translation" in w for w in fv.warnings)
            check(f"captions language: {name}", (track, human) == want and said == warned,
                  f"got {(track, human)}, warned={said}")


def test_track_type_decides_rolling():
    # Review round 3, finding 4: the caller passes the track type; style tags alone do not make a track machine.
    with tempfile.TemporaryDirectory() as d:
        p = os.path.join(d, "c.vtt")
        with open(p, "w") as f:
            f.write(STYLED_REPEAT)
        try:
            human = [t for _, t in fv.vtt_segments(p, machine=False)]
            machine = [t for _, t in fv.vtt_segments(p, machine=True)]
        except TypeError as e:
            check("the track type decides whether repeats roll", False, repr(e))
            return
        check("the track type decides whether repeats roll", human == ["Yes.", "Yes."] and machine == ["Yes."],
              f"human={human} machine={machine}")


for t in (test_captions_keep_real_repeats, test_captions_drop_rolling_repeats, test_frame_cap_limits_all_frames,
          test_stale_media_is_not_used, test_human_captions_keep_adjacent_repeats, test_reused_folder_drops_old_artifacts,
          test_cleanup_keeps_the_input_file, test_cleanup_keeps_a_link_the_input_runs_through,
          test_ytdlp_ignores_its_settings_files, test_captions_language_choice, test_track_type_decides_rolling):
    t()
print(f"{'FAILED' if failed else 'passed'}: {failed} failure(s)")
sys.exit(1 if failed else 0)
