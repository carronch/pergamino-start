---
name: benchmark-checklist
description: "Vet a measured number (a speedup, a regression, a cost, a benchmark score, an agent evaluation result) before you report or act on it: limiter, tuning, limits, errors, repeatability, relevance, and whether the work happened. Use when the author types /benchmark-checklist, asks 'is this number real?' or 'check this benchmark', or before you report a number you measured."
disable-model-invocation: true
---

# Benchmark checklist

Adapted from pstack's `benchmark-checklist` skill (Lauren Tan, MIT licence; `cursor/plugins`, commit `9d76bca`). This copy gives macOS and Linux commands and adds a section for agent and model benchmarks.

Use this when you produce a number: a before and after, a regression claim, a cost per run, a benchmark arm, or a library or configuration choice. Answer each question with evidence from a run, not a guess about the code.

For a quick ballpark that the author asked for, one run is enough. Still check questions 4 and 7, and say that it is one run. Skip the rest unless that run looks wrong. A choice between options is never a ballpark.

## Before you run anything

- Write down the claim you expect to make, in the words you would ship ("the full setup is 40% cheaper per correct answer on these 13 questions"). The questions test that sentence.
- Read the measurement script. Note what it times, counts and ignores.
- Check the load with `uptime`. Check the core count with `sysctl -n hw.ncpu` (macOS) or `nproc` (Linux). If the machine is busy, find out what is running (`top -o cpu` on macOS, `top` on Linux). If you cannot stop it, interleave the sides so that both see the same noise, and say so in the report. A laptop with the lid closed can sleep: check the power settings (`pmset -g` on macOS) before a long run.

## The questions

1. **Why not double?** Name the limiter. Profile in a run you do not report, because profilers slow the work down. Use CPU per process (`top`, `ps`), a runtime profiler (`node --cpu-prof`, `py-spy`, `sample <pid>` on macOS, `perf` on Linux), and input/output wait, then map the hot spot to source. Watch the load generator too: if it saturates first, you measured the load generator. If a change did not move the number, the limiter explains why, so find it before you call the change useless.
2. **Was it tuned?** Run every side the way production runs it: release builds, production flags and environment, batching, connection pools, caches as warm or cold as production sees them, and the same versions and data. If one side runs on defaults, you compared configurations, not implementations. A limiter that is a setting (a debug build, a missing index, a small page cache) means that side is untuned. Tune it and measure again before you pick a winner.
3. **Did it break limits?** Do the arithmetic. Compare bytes per second with disk and network bandwidth, and operations per second times cost per operation with your cores. Removing a piece that takes 10% of the run can make the run at most about 11% faster. A result past a limit measured something other than the work, such as a cache, a no-op or a bug.
4. **Did it error?** Count failures and non-success responses, and check that outputs are correct, not just present. Rejections are often fast; timeouts and retries are slow. If the script does not count errors, add the count.
5. **Does it reproduce?** Run each side at least 5 times, alternating (A, B, A, B) so that warmup, caches and drift favor neither. Report the median and the range. A gap smaller than the run-to-run variation is no measurable difference.
6. **Does it matter?** Next to any micro result, measure the end-to-end path that a user waits on, and report the micro result as a share of the whole. A helper that takes 1% of a request can make the request at most 1% faster.
7. **Did it even happen?** Confirm the work ran inside the timed region: the request reached the server, the rows were written, the code used the result. Lazy code (unawaited promises, unused results) and timeouts produce numbers for work that never happened.

## Agent and model benchmarks

The same seven questions apply. These points add to them:

- **Fixed tasks.** Hold the tasks, the starting state, the tools and the limits fixed for every arm. Change one thing per comparison.
- **Repeat and pair.** Run each task several times per arm. Report pass^k (all k tries pass) next to pass@k (one of k passes), and compare arms task by task, not only by mean.
- **Cost from the right source.** Use the cost that the tool reports for the run (for Claude Code, the cost line from `claude -p --output-format json` (`total_cost_usd`, `usage`) or `/cost`). Never use a live token counter: it can understate the cost several times over.
- **Did the agent do the work?** Check the transcript: the tools ran, and the answer came from this run, not from a cached file or an earlier session.
- **Plan limits are not prices.** A subscription weighs tokens its own way; say which one you measured.

## Report

- Lead with the verdict: faster, slower, cheaper, no measurable difference, or inconclusive.
- Give the number with its unit, the run count, the range and the limiter. For example: "p50 41 ms → 33 ms, median of 7 runs per side, range 32 to 35 ms after, bound by JSON parsing on one core."
- Call the verdict inconclusive when you claim a difference but cannot name the limiter, when a side ran untuned, or when you could not check questions 4 and 7. Name the gap.
- Keep a pull-request body to one primary number. Put the runs, the range and the limiter evidence in a linked file.
