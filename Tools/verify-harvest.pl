use strict; use warnings;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

# Refuse to ship a harvest that looks wrong
#
#   perl Tools/verify-harvest.pl            # check the JSON the harvests wrote
#   perl Tools/verify-harvest.pl --baked    # check what is already in index.html
#
# Exits non-zero on any failure, so a scheduled run stops before it commits.
#
# The app's first rule is that no price beats a wrong price. A harvest that
# half-fails is the one way that rule gets broken quietly: the shop changes a
# page, the parser matches less, and a smaller but perfectly well-formed file
# lands in the binder. Row counts are the cheapest thing that notices.

my $baked_mode = grep { $_ eq '--baked' } @ARGV;

# A missing harvest file is a failure by default, because in the workflow both
# harvesters run and a file that is not there means one of them died quietly.
# --partial says the single-shop run was deliberate: one shop is being
# rate-limited, the other answered, and baking the half that works beats
# throwing it away. The shop that is present is still checked in full.
my $partial = grep { $_ eq '--partial' } @ARGV;

# Floors, not targets. Set from what the shops actually carried on 2026-08-20,
# less the room a real week of stock movement needs. Raise them when the
# catalogues genuinely grow; a floor that never moves stops meaning anything.
my %FLOOR = (
  tcgc => 6000,      # 7,022 at last known-good
  pc   => 3000,      # 3,699
  jp   => 18000,     # 22,164
);
my $DROP_PCT = 15;   # versus the previous run, if we can see one

my (@fail, @warn, @note);

sub slurp {
  my $f = shift;
  open my $H, '<:raw', $f or return undef;
  local $/; my $s = <$H>; close $H;
  return eval { JSON::PP->new->utf8->decode($s) };
}

sub check_rows {
  my ($label, $key, $rows, $prev) = @_;
  unless (defined $rows) {
    if ($partial) { push @note, sprintf('%-14s skipped (--partial)', $label); return }
    push @fail, "$label: no file - did the harvest run?"; return;
  }
  my $n = scalar @$rows;
  push @note, sprintf('%-14s %6d rows', $label, $n);
  if ($n == 0)              { push @fail, "$label: zero rows" ; return }
  if ($n < $FLOOR{$key})    { push @fail, sprintf('%s: %d rows is below the floor of %d', $label, $n, $FLOOR{$key}) }
  if (defined $prev && $prev > 0) {
    my $drop = ($prev - $n) / $prev * 100;
    push @fail, sprintf('%s: %d rows is %.1f%% below the previous %d', $label, $n, $drop, $prev)
      if $drop > $DROP_PCT;
  }
  return $n;
}

# ---- how many rows does index.html hold right now? ----
# Used both as the "previous" figure for a fresh harvest and as the subject
# of --baked.
sub baked_counts {
  open my $H, '<:encoding(UTF-8)', 'index.html' or die "index.html: $!\n";
  local $/; my $h = <$H>; close $H;
  my %c;
  # Bounded by the markers, not by a line ending. The array is written on one
  # line by hand and one row per line by ae-bake.pl, so anything that assumes
  # a layout counts one of the two and silently reports zero for the other -
  # which is exactly what this script existed to catch, and did, on itself.
  if (my ($blk) = $h =~ /\/\* BAKED_PRICES_START \*\/(.*?)\/\* BAKED_PRICES_END \*\//s) {
    my $n = 0; $n++ while $blk =~ /\[\s*"[^"]*"\s*,\s*-?[\d.]+\s*,\s*[01]\s*\]/g;
    $c{tcgc} = $n;
  }
  if (my ($blk) = $h =~ /\/\* PC_PRICES_START \*\/(.*?)\/\* PC_PRICES_END \*\//s) {
    my $n = 0; $n++ while $blk =~ /\[\s*"[^"]*"\s*,\s*"[^"]*"\s*,/g;
    $c{pc} = $n;
  }
  if (my ($blk) = $h =~ /const JP_PRICES_RAW=`([^`]*)`/s) {
    my $n = 0; $n++ while $blk =~ /;/g;
    $c{jp} = $n;
  }
  return \%c;
}

# ---- which sets each side holds ----
# Row counts alone do not notice a set going missing, and that is the failure
# that actually happened: a throttled harvest lost ALIN, ES01, RC04, SDID,
# SDRB, SDSS, SLF1 and TFTV from Players Club - eight whole sets, 606 rows -
# which is a 1.7% drop. The 15% rule waved it straight through, and the file
# was well formed, so nothing downstream complained either. A binder simply
# stopped knowing those sets existed.
#
# So the sets are compared by name, not just counted. A set the file already
# carries in quantity must still be there.
sub prefixes_in {
  my ($rows, $ix) = @_;
  my %p;
  for my $r (@$rows) {
    my $c = $r->[$ix] // '';
    $p{ uc $1 }++ if $c =~ /^([A-Z0-9]{2,6})-AE/i;
  }
  return \%p;
}

sub baked_prefixes {
  open my $H, '<:encoding(UTF-8)', 'index.html' or return {};
  local $/; my $h = <$H>; close $H;
  my %out;
  for my $pair ( [ 'tcgc', 'BAKED_PRICES' ], [ 'pc', 'PC_PRICES' ] ) {
    my ( $key, $marker ) = @$pair;
    my ($blk) = $h =~ /\/\* ${marker}_START \*\/(.*?)\/\* ${marker}_END \*\//s
      or next;
    my %p;
    $p{ uc $1 }++ while $blk =~ /^\["([A-Z0-9]{2,6})-AE/gm;
    $out{$key} = \%p;
  }
  return \%out;
}

# A set small enough to be a handful of stray listings can legitimately sell
# out and vanish; one the file leans on cannot.
my $SET_FLOOR = 20;

sub check_sets {
  my ( $label, $key, $now, $was ) = @_;
  return unless $now && $was && %$was;
  my @gone = grep { ( $was->{$_} // 0 ) >= $SET_FLOOR && !$now->{$_} }
             sort keys %$was;
  push @note, sprintf( '%-14s %6d sets', $label, scalar keys %$now );
  return unless @gone;
  push @fail, sprintf(
    '%s: %d set%s present in the baked file is now completely absent - %s',
    $label, scalar @gone, @gone == 1 ? '' : 's',
    join( ', ', map { "$_ (was $was->{$_} rows)" } @gone ) );
}

my $baked = baked_counts();

if ($baked_mode) {
  print "checking what is already baked into index.html\n\n";
  check_rows('TCG Corner',   'tcgc', [ (1) x ($baked->{tcgc} // 0) ]);
  check_rows('Players Club', 'pc',   [ (1) x ($baked->{pc}   // 0) ]);
  check_rows('Yuyu-tei',     'jp',   [ (1) x ($baked->{jp}   // 0) ]);
} else {
  print "checking the files the harvests wrote\n\n";
  my $tc = slurp('tcgc-prices.json');
  my $pc = slurp('pc-prices.json');
  check_rows('TCG Corner',   'tcgc', $tc ? $tc->{rows} : undef, $baked->{tcgc});
  check_rows('Players Club', 'pc',   $pc ? $pc->{rows} : undef, $baked->{pc});

  # and no set may disappear outright - the code column is 0 in both shapes
  my $was = baked_prefixes();
  check_sets('TCG Corner',   'tcgc', $tc ? prefixes_in($tc->{rows}, 0) : undef, $was->{tcgc});
  check_sets('Players Club', 'pc',   $pc ? prefixes_in($pc->{rows}, 0) : undef, $was->{pc});

  # A harvest whose rows are all one shape is a parser that stopped reading.
  for my $pair ([ 'TCG Corner', $tc, 3 ], [ 'Players Club', $pc, 1 ]) {
    my ($label, $j, $ri) = @$pair;
    next unless $j && $j->{rows} && @{ $j->{rows} };
    my %rar; $rar{ $_->[$ri] // '' }++ for @{ $j->{rows} };
    my $kinds = scalar keys %rar;
    push @fail, "$label: every row has the same rarity tag - parser drift?" if $kinds < 2;
    my $blank = $rar{''} // 0;
    my $pct = $blank / scalar(@{ $j->{rows} }) * 100;
    push @warn, sprintf('%s: %.0f%% of rows carry no rarity tag', $label, $pct) if $pct > 20;
    push @note, sprintf('%-14s %6d distinct rarity tags', $label, $kinds);
  }
  # a stamp from the future or the distant past means a clock or a cache problem
  for my $pair ([ 'TCG Corner', $tc ], [ 'Players Club', $pc ]) {
    my ($label, $j) = @$pair;
    next unless $j && $j->{t};
    my @t = localtime; my $today = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];
    push @warn, "$label: stamped $j->{t}, today is $today" if $j->{t} gt $today;
  }
}

print "$_\n" for @note;
print "\n";
print "WARN  $_\n" for @warn;
print "FAIL  $_\n" for @fail;

if (@fail) {
  printf "\n%d check%s failed - not safe to bake or commit\n", scalar @fail, @fail == 1 ? '' : 's';
  exit 1;
}
print "\nall checks passed\n";
exit 0;
