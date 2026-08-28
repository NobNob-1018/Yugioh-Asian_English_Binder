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
my $COLL = 'ygoae1';
my $BASE = "https://playersclubhk.com/en/collections/$COLL/products.json";
my $OUT  = 'pc-prices.json';

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

my (@rows, $skipped, $norar);
$skipped = 0; $norar = 0;
for my $page (1 .. 40) {
  my $url = "$BASE?limit=250&page=$page";
  printf "page %2d ... ", $page;
  my $body = `curl -s -m 60 -A "$UA" "$url"`;
  my $j = eval { JSON::PP->new->utf8->decode($body) };
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
    $norar++ unless $t->{rar};
    push @rows, [ $t->{code}, $t->{rar}, $price, $t->{name}, $av ];
  }
  printf "%d products, %d priced so far\n", scalar @$products, scalar @rows;
  last if @$products < 250;
  sleep 1;                      # be polite to their server
}

unless (@rows) { die "nothing harvested - is the collection name still '$COLL'?\n" }

my @t = localtime; my $date = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];
open my $O, '>:raw', $OUT or die "$OUT: $!\n";
print $O JSON::PP->new->utf8->canonical->encode({ t => $date, cur => 'HKD', rows => \@rows });
close $O;

printf "\n%d prices -> %s\n", scalar @rows, $OUT;
printf "%d listings skipped (no AE code or no price)\n", $skipped if $skipped;
printf "%d rows carry no rarity tag - the app treats those as unmatched\n", $norar if $norar;
