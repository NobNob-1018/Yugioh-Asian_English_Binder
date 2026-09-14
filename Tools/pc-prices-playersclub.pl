use strict; use warnings;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

# Pull the Players Club HK Asian-English list into pc-prices.json
#
#   perl Tools/pc-prices-playersclub.pl
#
# The second Asian-English shop. README section 9 has described this endpoint
# and its quirks since the shop was added, but the harvester itself was never
# written - the rows in the file were produced by hand. That meant the AE side
# could not be re-harvested without a person, which is the whole reason the
# prices go stale.
#
# Rows are [code, rarity, price, name, available] - the shape PC_ROWS_RAW
# holds, minus the name-index packing that Tools/ae-bake.pl applies.

my $UA   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';
my $SHOP = 'https://playersclubhk.com/en';
my $SEED = 'ygoae1';             # the general Asian-English shelf
my $OUT  = 'pc-prices.json';

# ---- one collection was not the whole shop ----
# This read ygoae1 and nothing else, on the documented understanding that the
# shop keeps its Asian-English stock in a single collection. It does not, or it
# stopped: BPRO-AE and BLZD-AE are each in a collection of their own and were
# never filed into ygoae1, so every card in them was missing from the file.
#
# The failure was silent and it looked like something else entirely. bestMatch()
# compares two shops and names the cheaper; with one side absent it returns the
# other with only:true, so a card Players Club sells for HK$100 was quoted at
# TCG Corner's P1,538 with nothing to say a second shop had it cheaper. It reads
# as the comparison choosing wrong. The comparison was never offered the row.
#
# So the shop's own collection list decides what to read: every collection whose
# title names an AE set - that is their convention, "1303 BPRO-AE BURST
# PROTOCOL" - plus ygoae1 itself. A set that gets its own collection next month
# is picked up without anyone noticing it had to be.
#
# Overlap is expected and harmless: a card in both ygoae1 and its own set
# collection is emitted twice, and pcIndex() in the app already resolves a
# duplicate code+rarity the right way round - in stock beats cheaper, then
# cheaper wins.

sub fetch_json {
  my $url = shift;
  my $body = `curl -s -m 60 -A "$UA" "$url"`;
  return eval { JSON::PP->new->utf8->decode($body) };
}

# Every collection that names an Asian-English set, plus the general shelf.
sub ae_collections {
  my %seen = ($SEED => 1);
  my @out  = ($SEED);
  for my $page (1 .. 10) {
    my $j = fetch_json("$SHOP/collections.json?limit=250&page=$page") or last;
    my $c = $j->{collections} || [];
    last unless @$c;
    for my $x (@$c) {
      my $title  = $x->{title}  // '';
      my $handle = $x->{handle} // '';
      next unless $title =~ /\b[A-Z0-9]{2,6}-AE\b/i;
      next if $seen{$handle}++;
      push @out, $handle;
    }
    last if @$c < 250;
  }
  return @out;
}

# Their titles carry the rarity in the title rather than a field, and the
# spacing is inconsistent:
#   "25AT-AE304 (SR)Lose 1 Turn"   rarity bracketed, glued to the name
#   "DUNE-AE107(UR)"               no name at all
#   "ROTA-AE001 Witness (Overframe)"  full word, not an abbreviation
#
# The abbreviation is left exactly as the shop wrote it: ourRar() in the app
# owns every spelling both shops use, and a second mapping here would be a
# second place to keep in step.
sub parse_title {
  my $raw = shift // '';
  return undef unless $raw =~ /^\s*([A-Z0-9]{2,6}-AE[SC]?[0-9]{2,3})\s*(.*)$/i;
  my ($code, $rest) = (uc($1), $2);

  my $rar = '';
  # the rarity bracket can sit anywhere in what is left; take the first one
  # that looks like a rarity rather than part of a card name
  if ($rest =~ s/\(\s*([A-Za-z][A-Za-z'\x{2019}.\- ]*?)\s*\)//) { $rar = uc($1); }
  $rar =~ s/\s+$//;

  $rest =~ s/\s+/ /g;
  $rest =~ s/^\s+|\s+$//g;
  return { code => $code, name => $rest, rar => $rar };
}

my (@rows, %emitted, $skipped, $norar);
$skipped = 0; $norar = 0;

my @colls = ae_collections();
printf "%d Asian-English collections to read\n\n", scalar @colls;

for my $coll (@colls) {
  printf "%s\n", $coll;
  my $before = scalar @rows;
  for my $page (1 .. 40) {
    my $url = "$SHOP/collections/$coll/products.json?limit=250&page=$page";
    printf "  page %2d ... ", $page;
    my $j = fetch_json($url);
    unless ($j) { print "no JSON - stopping\n"; last }
    my $products = $j->{products} || [];
    unless (@$products) { print "empty - done\n"; last }

    for my $p (@$products) {
      my $t = parse_title($p->{title});
      unless ($t) { $skipped++; next }
      my $v = ($p->{variants} && $p->{variants}[0]) || {};
      my $price = $v->{price};
      $price = defined $price ? $price + 0 : 0;
      unless ($price > 0) { $skipped++; next }
      my $av = exists $v->{available} ? ($v->{available} ? 1 : 0) : 1;
      # the same listing reached from two collections is one listing
      my $key = join '|', $t->{code}, $t->{rar}, $price, $av;
      next if $emitted{$key}++;
      $norar++ unless $t->{rar};
      push @rows, [ $t->{code}, $t->{rar}, $price, $t->{name}, $av ];
    }
    printf "%d products, %d rows so far\n", scalar @$products, scalar @rows;
    last if @$products < 250;
    sleep 1;                      # be polite to their server
  }
  printf "  +%d\n\n", scalar(@rows) - $before;
}

unless (@rows) { die "nothing harvested - is '$SEED' still a collection?\n" }

my @t = localtime; my $date = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];
open my $O, '>:raw', $OUT or die "$OUT: $!\n";
print $O JSON::PP->new->utf8->canonical->encode({ t => $date, cur => 'HKD', rows => \@rows });
close $O;

printf "\n%d prices -> %s\n", scalar @rows, $OUT;
printf "%d listings skipped (no AE code or no price)\n", $skipped if $skipped;
printf "%d rows carry no rarity tag - the app treats those as unmatched\n", $norar if $norar;
