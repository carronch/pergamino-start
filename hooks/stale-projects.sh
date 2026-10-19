#!/bin/bash
# SessionStart hook: nudge about projects with no movement.
# A "project" = a card in <LLM brain>/wiki/workblocks/ tagged `rollup`. Its last activity = the
# newest ISO date visible on the rollup or any card it wikilinks (frontmatter
# updated:/date:/created:, `- YYYY-MM-DD:` timeline lines, or the file name).
# Quiet >= STALE_DAYS (default 7) => one nudge line. Read-only, always exits 0.
# One perl pass over the cards: a grep, sort and date call per card is slow at a few hundred
# cards. A project quiet exactly STALE_DAYS days is always nudged: both dates are taken at noon,
# so a second that ticks during the run cannot drop it.
# Tests: hooks/session-start.test.sh.

[ -t 0 ] || cat >/dev/null 2>&1 || true   # the hook input is not needed
. "$(dirname "$0")/lib/paths.sh"
[ -n "${PERGAMINO_LLM_BRAIN:-}" ] || exit 0
WB="$PERGAMINO_LLM_BRAIN/wiki/workblocks"
[ -d "$WB" ] || exit 0
THRESHOLD="${STALE_DAYS:-7}"

# The program goes in a variable first: bash 3.2 misparses a heredoc inside $( ).
IFS= read -r -d '' PL <<'PERL'
use strict; use warnings;
use Time::Local qw(timelocal);
my $threshold = shift @ARGV;
$threshold = 7 unless defined $threshold && $threshold =~ /^[0-9]+\z/;
my %memo;
sub card {   # per card: rollup tag, newest date, first title line, wikilink targets
  my ($file) = @_;
  return $memo{$file} if exists $memo{$file};
  my %c = (rollup => 0, title => undef, links => {});
  my @dates;
  push @dates, $1 if $file =~ /^([0-9]{4}-[0-9]{2}-[0-9]{2})/;
  if (open my $fh, '<', $file) {
    while (my $l = <$fh>) {
      chomp $l;
      $c{rollup} = 1 if $l =~ /^tags:.*[\[,[:space:]]rollup[\],[:space:]]/;
      push @dates, $1 if $l =~ /^(?:updated|created|date): *"?([0-9]{4}-[0-9]{2}-[0-9]{2})/
                      or $l =~ /^- ([0-9]{4}-[0-9]{2}-[0-9]{2}):/;
      $c{title} = $l if !defined $c{title} && $l =~ /^title:/;
      # Last path segment of each wikilink. rindex, not m{([^/]*)\z}: that regex is
      # quadratic on a long link ending in '/' (10 s at 40,000 characters).
      while ($l =~ /\[\[([^\]|]+)/g) { my $link = $1; my $id = substr($link, rindex($link, "/") + 1); $c{links}{$id} = 1 }
    }
    close $fh;
  }
  my ($newest) = sort { $b cmp $a } @dates;
  $c{date} = defined $newest ? $newest : '';
  return $memo{$file} = \%c;
}
my @lt = localtime;
my $today = timelocal(0, 0, 12, $lt[3], $lt[4], $lt[5]);
for my $f (@ARGV) {
  my $c = card($f);
  next unless $c->{rollup};
  my $last = $c->{date};
  for my $id (keys %{ $c->{links} }) {
    next unless -f "$id.md";
    my $d = card("$id.md")->{date};
    $last = $d if $d ne '' && $d gt $last;
  }
  my ($yy, $mm, $dd) = $last =~ /^([0-9]{4})-([0-9]{2})-([0-9]{2})\z/ or next;
  my $ts = eval { timelocal(0, 0, 12, $dd, $mm - 1, $yy) };
  next unless defined $ts;
  next unless sprintf('%.0f', ($today - $ts) / 86400) >= $threshold;
  my $title = defined $c->{title} ? $c->{title} : '';
  $title =~ s/^title: *//; $title =~ s/^"//; $title =~ s/"$//;
  (my $base = $f) =~ s/\.md\z//;
  print "\n- ", ($title ne '' ? $title : $base), " — last movement $last. Card: wiki/workblocks/$f";
}
PERL

PERL_BIN=/usr/bin/perl; [ -x "$PERL_BIN" ] || PERL_BIN=$(command -v perl 2>/dev/null) || exit 0
out=$(cd "$WB" && "$PERL_BIN" -e "$PL" "$THRESHOLD" *.md 2>/dev/null)
[ -n "$out" ] || exit 0
jq -n --arg c "Projects with no movement for ${THRESHOLD} days or more. Mention them to the author when it fits; one small next step is enough to wake a project:$out" '{
  hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: $c }
}'
exit 0
