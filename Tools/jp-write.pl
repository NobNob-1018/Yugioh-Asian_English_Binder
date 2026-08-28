use strict; use warnings;
use JSON::PP;
use FindBin;
binmode(STDOUT, ':encoding(UTF-8)');

# Put the OCG-JP blocks into index.html
#
#   perl Tools/jp-sets.pl
#   perl Tools/jp-prices-yuyutei.pl
#   perl Tools/jp-catalogue-yugipedia.pl
#   perl Tools/jp-bake.pl                  -> /tmp/jp_blocks.json
#   perl Tools/jp-write.pl --dry-run       -> says what would change
#   perl Tools/jp-write.pl                 -> rewrites index.html
#
# jp-bake.pl stops at a JSON file and always has. The four blocks were then
# pasted into index.html by hand, which is why OCG-JP could not be refreshed
# without a person, and why the scheduled job could harvest all four scripts
# and then change nothing at all.
#
# Everything here refuses rather than guesses. These are HTML scrapes of
# Yugipedia and Yuyu-tei, not JSON endpoints: a layout change does not error,
# it just returns less. So the checks below are about SHAPE - is this still
# the thing we think it is - and a failure writes nothing.

my $DRY = grep { $_ eq '--dry-run' || $_ eq '-n' } @ARGV;
my $TMP = $ENV{JP_TMP} || '/tmp';
my $HTML = $FindBin::Bin . '/../index.html';
my $BLOCKS = "$TMP/jp_blocks.json";

# Floors from the last known-good harvest, less the room a real month of new
# sets needs. Raise them when the catalogue genuinely grows; a floor that
# never moves stops meaning anything.
my %FLOOR = (
  cat_sets      => 380,     # 454 at last known-good
  priced_rows   => 18000,   # 22,164
  # Yuyu-tei carries 257 of those 454 sets, not all of them - a shop stocks
  # what sells. My first guess at this floor was 300 and the check failed on
  # perfectly good data, which is the failure mode a floor set by hope rather
  # than measurement always has.
  priced_sets   => 200,
  names         => 2000,    # 5,688
);
my $DROP_PCT = 15;          # against what is in index.html now

my (@fail, @note);

open my $B, '<:raw', $BLOCKS or die "$BLOCKS: $! - run Tools/jp-bake.pl first\n";
my $blocks = do { local $/; JSON::PP->new->utf8->decode(<$B>) };
close $B;

my $cat    = $blocks->{cat}    // '';
my $prices = $blocks->{prices} // '';
my $names  = $blocks->{names}  // [];
my $rkeys  = $blocks->{rkeys}  // [];

# ---- shape checks ----
my $cat_sets    = ($cat    =~ tr/\n//) + ($cat    ? 1 : 0);
my $priced_sets = ($prices =~ tr/\n//) + ($prices ? 1 : 0);
my $priced_rows = () = $prices =~ /;/g;
$priced_rows += $priced_sets;                    # last row of each line has no ;

push @note, sprintf('%-16s %6d', 'catalogue sets', $cat_sets);
push @note, sprintf('%-16s %6d', 'priced sets',    $priced_sets);
push @note, sprintf('%-16s %6d', 'priced rows',    $priced_rows);
push @note, sprintf('%-16s %6d', 'extra names',    scalar @$names);
push @note, sprintf('%-16s %6d', 'rarity keys',    scalar @$rkeys);

push @fail, "catalogue is empty"        unless $cat_sets;
push @fail, "price table is empty"      unless $priced_rows;
push @fail, sprintf('catalogue sets %d is below the floor of %d', $cat_sets, $FLOOR{cat_sets})
  if $cat_sets && $cat_sets < $FLOOR{cat_sets};
push @fail, sprintf('priced rows %d is below the floor of %d', $priced_rows, $FLOOR{priced_rows})
  if $priced_rows && $priced_rows < $FLOOR{priced_rows};
push @fail, sprintf('priced sets %d is below the floor of %d', $priced_sets, $FLOOR{priced_sets})
  if $priced_sets && $priced_sets < $FLOOR{priced_sets};
push @fail, sprintf('extra names %d is below the floor of %d', scalar @$names, $FLOOR{names})
  if @$names && @$names < $FLOOR{names};

# The rarity ladder is fixed at nineteen. A scrape that suddenly knows a
# different number of rarities has found a page it does not understand.
push @fail, sprintf('rarity keys %d, expected 19', scalar @$rkeys)
  if @$rkeys && @$rkeys != 19;

# A price line is PRE|num,rarIdx,yen,qty;... - if the shape drifted, the app
# would parse silence rather than fail, so it is checked here instead.
if ($prices) {
  my ($first) = split /\n/, $prices;
  push @fail, "price lines are not PRE|num,rar,yen,qty"
    unless $first =~ /^[A-Z0-9]{2,8}\|[^,]+,\d+,\d+,\d+/;
  my $zero = () = $prices =~ /,0,0(?:;|$)/g;
  push @fail, sprintf('%d priced rows are zero yen and zero stock', $zero)
    if $zero > $priced_rows * 0.2;
}
# Every priced code should be one the catalogue knows. Orphans mean a parser
# drifted - this is the check the README has always described in prose.
if ($cat && $prices) {
  my %known = map { (split /\|/, $_)[0] => 1 } split /\n/, $cat;
  my @orphan = grep { !$known{$_} } map { (split /\|/, $_)[0] } split /\n/, $prices;
  push @note, sprintf('%-16s %6d', 'orphan sets', scalar @orphan);
  push @fail, sprintf('%d priced sets are not in the catalogue: %s',
    scalar @orphan, join(', ', (sort @orphan)[0 .. ($#orphan > 4 ? 4 : $#orphan)]))
    if @orphan > 5;
}

# ---- what is in index.html now, for the drop check ----
open my $H, '<:encoding(UTF-8)', $HTML or die "$HTML: $!\n";
my $html = do { local $/; <$H> };
close $H;

# Find `const NAME=` and the end of its value, whatever the value's shape.
# index() rather than a character walk: these values are hundreds of
# kilobytes inside a 1.6 MB file, and stepping through that a character at a
# time takes minutes.
sub span {
  my ($src, $name) = @_;
  return () unless $src =~ /const \Q$name\E\s*=\s*/;
  my $start = $-[0];
  my $i = $+[0];
  my $open = substr($src, $i, 1);
  if ($open eq '`' || $open eq q{'} || $open eq q{"}) {
    my $k = $i + 1;
    while (1) {
      my $e = index($src, $open, $k);
      return () if $e < 0;
      # count the backslashes immediately before it; an odd number escapes it
      my $b = $e - 1;
      $b-- while $b >= 0 && substr($src, $b, 1) eq '\\';
      return ($start, $e + 1) if (($e - 1 - $b) % 2) == 0;
      $k = $e + 1;
    }
  }
  if ($open eq '[' || $open eq '{') {
    my $close = $open eq '[' ? ']' : '}';
    my ($d, $k) = (0, $i);
    while ($k < length $src) {
      my $o = index($src, $open,  $k);
      my $c = index($src, $close, $k);
      return () if $c < 0;
      if ($o >= 0 && $o < $c) { $d++; $k = $o + 1 }
      else { $d--; return ($start, $c + 1) unless $d; $k = $c + 1 }
    }
  }
  return ();
}

my %old;
for my $n (qw(JP_CAT_RAW JP_PRICES_RAW JP_NAMES_EXTRA JP_RKEYS)) {
  my ($a, $b) = span($html, $n);
  unless (defined $a) { push @fail, "could not find const $n in index.html"; next }
  $old{$n} = [$a, $b, substr($html, $a, $b - $a)];
}
unless (@fail) {
  my $oldCatSets = () = $old{JP_CAT_RAW}[2] =~ /\n/g;
  my $oldRows    = () = $old{JP_PRICES_RAW}[2] =~ /;/g;
  push @note, sprintf('%-16s %6d -> %d', 'was catalogue', $oldCatSets, $cat_sets);
  push @note, sprintf('%-16s %6d -> %d', 'was priced', $oldRows, $priced_rows);
  push @fail, sprintf('catalogue dropped %.1f%%, from %d sets to %d',
    ($oldCatSets - $cat_sets) / $oldCatSets * 100, $oldCatSets, $cat_sets)
    if $oldCatSets > 0 && ($oldCatSets - $cat_sets) / $oldCatSets * 100 > $DROP_PCT;
  push @fail, sprintf('prices dropped %.1f%%, from %d rows to %d',
    ($oldRows - $priced_rows) / $oldRows * 100, $oldRows, $priced_rows)
    if $oldRows > 0 && ($oldRows - $priced_rows) / $oldRows * 100 > $DROP_PCT;
}

print "$_\n" for @note;
print "\n";
if (@fail) {
  print "FAIL  $_\n" for @fail;
  printf "\n%d check%s failed - index.html was NOT changed\n",
    scalar @fail, @fail == 1 ? '' : 's';
  exit 1;
}
print "all checks passed\n";

if ($DRY) { print "\n--dry-run: nothing written\n"; exit 0 }

# ---- write, back to front so the offsets stay valid ----
my $J = JSON::PP->new->utf8(0)->canonical;
my %new = (
  JP_CAT_RAW     => 'const JP_CAT_RAW=`'    . $cat    . '`',
  JP_PRICES_RAW  => 'const JP_PRICES_RAW=`' . $prices . '`',
  JP_NAMES_EXTRA => 'const JP_NAMES_EXTRA=' . $J->encode($names),
  JP_RKEYS       => 'const JP_RKEYS='       . $J->encode($rkeys),
);
# A backtick or a ${ in scraped text would end the template literal early and
# turn the rest of the file into syntax errors.
for my $k (qw(JP_CAT_RAW JP_PRICES_RAW)) {
  die "$k contains a backtick or \${ - refusing to write\n"
    if $new{$k} =~ /(?<!\\)\$\{/ || ($new{$k} =~ tr/`//) != 2;
}
for my $n (sort { $old{$b}[0] <=> $old{$a}[0] } keys %old) {
  substr($html, $old{$n}[0], $old{$n}[1] - $old{$n}[0]) = $new{$n};
}

open my $O, '>:encoding(UTF-8)', $HTML or die "$HTML: $!\n";
print $O $html; close $O;
printf "\nwritten to %s  (%.1f KB)\n", $HTML, (-s $HTML) / 1024;
