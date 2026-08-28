use strict; use warnings;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

# Write both Asian-English shops into index.html
#
#   perl Tools/ae-prices-tcgcorner.pl      -> tcgc-prices.json
#   perl Tools/pc-prices-playersclub.pl    -> pc-prices.json
#   perl Tools/ae-bake.pl                  -> rewrites index.html
#
# The OCG-JP side has had jp-bake.pl since it was added; the Asian-English side
# never did. Its harvest stopped at a JSON file and a person pasted rows over
# the BAKED_PRICES array by hand, which is why README section 2 carries a
# warning about the two export paths that silently drop printings. This closes
# that gap, so both regions re-harvest the same way.
#
# Nothing here interprets a rarity. The shops' own tags are passed through
# untouched, because ourRar() in the app already owns every spelling both
# shops use, and a second mapping in this file would be a second thing to
# keep in step.

my $HTML = 'index.html';

# ---- read what the harvests produced ----
sub slurp_json {
  my $f = shift;
  open my $H, '<:raw', $f or die "$f: $! - run the harvester first\n";
  local $/; my $s = <$H>; close $H;
  return JSON::PP->new->utf8->decode($s);
}

my $tc = slurp_json('tcgc-prices.json');
my $pc = slurp_json('pc-prices.json');

# ---- the shared name table ----
# AE_NAMES already exists in the file. Names are stored as an index into it
# wherever possible and as a literal string otherwise, which is what keeps
# these two blocks to a few hundred KB rather than a few megabytes.
# Read as characters, not bytes. The JSON above already decoded to characters,
# and mixing the two is how this project has corrupted an em-dash before: the
# file must be characters from here to the write, and encoded exactly once.
open my $H, '<:encoding(UTF-8)', $HTML or die "$HTML: $!\n";
local $/; my $html = <$H>; close $H;

my ($names_src) = $html =~ /const AE_NAMES=(\[.*?\]);/s
  or die "could not find AE_NAMES in $HTML\n";
my $names = JSON::PP->new->decode($names_src);
my %name_ix;
for my $i (0 .. $#$names) { $name_ix{ $names->[$i] } //= $i; }
printf "AE_NAMES holds %d names\n", scalar @$names;

my $packname = sub {
  my $n = shift // '';
  return '' unless length $n;
  return exists $name_ix{$n} ? $name_ix{$n} + 0 : $n;
};

# ---- TCG Corner -> BAKED_PRICES ----
# Grouped by code so each printing's rarities sit together:
#   [code, nameIndexOrString, [[rarity, price, available], ...]]
# Played copies are dropped: the app only ever quotes clean ones, and the
# used prices live in Tools/played-stock.json instead.
my (%by_code, @order, $played, $unrar, $kept);
$played = 0; $unrar = 0; $kept = 0;
for my $r (@{ $tc->{rows} }) {
  my ($code, $price, $name, $rar, $cond, $av) = @$r;
  if ($cond) { $played++; next }
  $unrar++ unless defined $rar && length $rar;
  $av = defined $av ? ( $av ? 1 : 0 ) : 1;
  # Every row is kept. An earlier draft collapsed one row per code+rarity and
  # lost 43 printings the file already held: a shop really does list the same
  # printing twice, and indexPrices() already picks between them at runtime -
  # in stock over cheaper - so choosing here would only mean choosing twice,
  # in two places, by two different rules.
  push @order, $code unless exists $by_code{$code};
  $by_code{$code}{name} //= $name;
  push @{ $by_code{$code}{rars} }, [ $rar // '', $price + 0, $av ];
  $kept++;
}
my @baked;
for my $code (@order) {
  my $e = $by_code{$code};
  push @baked, [ $code, $packname->( $e->{name} ), $e->{rars} ];
}
printf "TCG Corner: %d codes, %d printings (%d played dropped, %d without a rarity)\n",
  scalar @baked, $kept, $played, $unrar;

# ---- Players Club -> PC_ROWS_RAW ----
# Flat, one row per listing: [code, rarity, price, nameIndexOrString, available]
# The app's pcIndex() does its own de-duplication, so rows are passed straight
# through rather than collapsed here - collapsing in two places is how the
# two shops would drift apart.
my @pcrows;
for my $r (@{ $pc->{rows} }) {
  my ($code, $rar, $price, $name, $av) = @$r;
  push @pcrows, [ $code, $rar // '', $price + 0, $packname->($name), $av ? 1 : 0 ];
}
printf "Players Club: %d rows\n", scalar @pcrows;

# ---- write both blocks back between their markers ----
my $J = JSON::PP->new->canonical->allow_nonref;
sub rows_text {                      # one row per line, as the file already has
  my $rows = shift;
  return join ",\n", map { $J->encode($_) } @$rows;
}

my $tc_date = $tc->{t} // '';
my $tc_cur  = $tc->{cur} // 'PHP';
my $pc_date = $pc->{t} // '';
my $pc_cur  = $pc->{cur} // 'HKD';

my $baked_block = "/* BAKED_PRICES_START */\n"
  . "const BAKED_STAMP='$tc_date';\n"
  . "const BAKED_CUR='$tc_cur';\n"
  . "const BAKED_PRICES=[\n" . rows_text( \@baked ) . "\n];\n"
  . "/* BAKED_PRICES_END */";

my ($pc_head) = $html =~ /(\/\* PC_PRICES_START \*\/.*?const PC_LINK=[^\n]*\n)/s
  or die "could not find the Players Club header block\n";
# the stamp and currency live in that header, so refresh them in place
$pc_head =~ s/const PC_STAMP='[^']*';/const PC_STAMP='$pc_date';/;
$pc_head =~ s/const PC_CUR='[^']*';/const PC_CUR='$pc_cur';/;
my $pc_block = $pc_head
  . "const PC_ROWS_RAW=[\n" . rows_text( \@pcrows ) . "\n];\n"
  . "/* PC_PRICES_END */";

my $hits = 0;
$hits += ( $html =~ s/\/\* BAKED_PRICES_START \*\/.*?\/\* BAKED_PRICES_END \*\//$baked_block/s );
$hits += ( $html =~ s/\/\* PC_PRICES_START \*\/.*?\/\* PC_PRICES_END \*\//$pc_block/s );
die "expected to replace 2 blocks, replaced $hits - markers moved?\n" unless $hits == 2;

# Card names carry non-ASCII - accented letters, the full-width middle dot -
# so the text is encoded to UTF-8 bytes before it is written. Writing wide
# characters to a raw handle is what produced the "Wide character" warning,
# and would have written a differently-encoded file than the one read.
open my $O, '>:encoding(UTF-8)', $HTML or die "$HTML: $!\n";
print $O $html; close $O;

printf "\nwritten to %s  (%.1f KB)\n", $HTML, ( -s $HTML ) / 1024;
print "run Tools/verify-harvest.pl before committing\n";
