use strict; use warnings;
use JSON::PP;
binmode(STDOUT, ':encoding(UTF-8)');

# Pull the TCG Corner Asia-English singles list into tcgc-prices.json
#
#   perl Tools/ae-prices-tcgcorner.pl
#
# A port of the old fetch-tcgc-prices.js. That one needed Node, which is not
# installed here, so the Asian-English harvest could not actually be run - while
# the OCG-JP scripts beside it are Perl and work. This closes that gap.
#
# Rows are [code, price, name, rarity, condition] - the shape the binder's
# Prices > Import expects, and the shape jp-bake.pl's AE counterpart reads.

my $UA   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';
my $COLL = 'yu-gi-oh-single-card-asia-english';
my $BASE = "https://tcg-corner.com/collections/$COLL/products.json";
my $OUT  = 'tcgc-prices.json';

# "CR12-AE097 Pressured Planet Wraitsoth (UL) (Status B)" ->
#   code CR12-AE097, name Pressured Planet Wraitsoth, rarity UL, condition B
sub parse_title {
  my $raw = shift // '';
  return undef unless $raw =~ /^\s*([A-Z0-9]{2,6}-AE[SC]?[0-9]{2,3})\s+(.*)$/i;
  my ($code, $rest) = (uc($1), $2);

  # Played stock is flagged as (Status A/B/C); some listings only say "damaged"
  my $cond = '';
  $cond = uc($1) if $raw =~ /\(\s*Status\s*([A-Za-z])\s*\)/i;
  $cond = 'D' if !$cond && $raw =~ /damaged|\bDMG\b|played/i;

  # rarity is the bracketed tag that is NOT the status one
  #
  # This used to cap the tag at five letters, which silently dropped every
  # rarity with a longer name. "Overframe" is nine, so a title like
  #   ROTA-AE001 Witness of the Ancient (Overframe)
  # lost its rarity AND kept "(Overframe)" glued to the card name, so the
  # name never matched the catalogue and the card vanished from the binder
  # entirely rather than merely arriving unrarified. Any bracketed word up
  # to twenty letters now counts, and the same pattern strips it from the
  # name, so the two can never disagree again.
  # The rarity tag is the LAST bracket on the line, so it is matched by
  # position rather than by length. Guessing a length is what broke this:
  # five letters lost "Overframe", twenty would still lose "Quarter Century
  # Secret Rare", and "Collector's Rare" carries an apostrophe. Anchoring to
  # the end takes whatever the shop wrote, however long, and leaves any
  # bracket earlier in the line - which belongs to the card name - alone.
  my $norar = $rest;
  $norar =~ s/\(\s*Status[^)]*\)\s*//gi;
  $norar =~ s/\s+$//;
  my $rar = '';
  $rar = uc($1) if $norar =~ /\(\s*([A-Za-z][A-Za-z'’.\- ]*?)\s*\)\s*$/;

  $rest =~ s/\(\s*Status[^)]*\)//gi;
  $rest =~ s/\(\s*[A-Za-z][A-Za-z'’.\- ]*?\s*\)\s*$//;
  $rest =~ s/\s+/ /g;
  $rest =~ s/^\s+|\s+$//g;
  return { code => $code, name => $rest, rar => $rar, cond => $cond };
}

my (@rows, $skipped);
$skipped = 0;
for my $page (1 .. 60) {
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
    # Stock, not just price. The app's rule is that an in-stock listing beats
    # a cheaper one you cannot actually buy, and it could not apply that rule
    # to Asian-English because this harvest never recorded availability.
    # Shopify says so per variant; absent means assume it is buyable rather
    # than quietly demote a shop that simply did not answer.
    my $av = exists $v->{available} ? ($v->{available} ? 1 : 0) : 1;
    push @rows, [ $t->{code}, $price, $t->{name}, $t->{rar}, $t->{cond}, $av ];
  }
  printf "%d products, %d priced so far\n", scalar @$products, scalar @rows;
  last if @$products < 250;
  sleep 1;                      # be polite to their server
}

unless (@rows) { die "nothing harvested - is the collection name still '$COLL'?\n" }

# Guess the currency the way the app does: their peso prices are far larger
# than the dollar ones, so the median separates them cleanly.
my @vals = sort { $a <=> $b } map { $_->[1] } @rows;
my $median = $vals[ int(@vals / 2) ] || 0;
my $cur = $median > 60 ? 'PHP' : 'USD';

my @t = localtime; my $date = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];
open my $O, '>:raw', $OUT or die "$OUT: $!\n";
print $O JSON::PP->new->utf8->canonical->encode({ t => $date, cur => $cur, rows => \@rows });
close $O;

printf "\n%d prices -> %s  (currency looks like %s, median %.2f)\n",
  scalar @rows, $OUT, $cur, $median;
printf "%d listings skipped (no AE code or no price)\n", $skipped if $skipped;

# Played stock, kept separately: the app only ever quotes clean copies, but the
# used prices are worth having when deciding what to buy or what a played copy
# of your own is worth.
my @played = grep { $_->[4] } @rows;
if (@played) {
  open my $P, '>:raw', 'Tools/played-stock.json' or die $!;
  print $P JSON::PP->new->utf8->canonical->encode({ t => $date, cur => $cur, rows => \@played });
  close $P;
  printf "%d played rows -> Tools/played-stock.json\n", scalar @played;
}
