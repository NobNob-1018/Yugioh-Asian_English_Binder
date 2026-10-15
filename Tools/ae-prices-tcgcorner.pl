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

# ---- one shelf was not the shop ----
# This read the collection 'yu-gi-oh-single-card-asia-english' and nothing
# else, on the understanding that every Asian-English single is filed there.
# They are not. CR13 (Creation Pack 13) released with 374 CR12 listings still
# sitting in that collection and not one CR13 listing in it, while the shop's
# own search returned CR13 singles the whole time - they had a collection of
# their own, 'cr13', and had never been filed across. The same shape of
# mistake as the Players Club one fixed beside this: a shelf mistaken for the
# shop.
#
# It fails silently and it does not look like a harvest problem. A whole set
# is absent, so the app has no printing to price, no member to count and no
# set to list - and the person pressing Sync concludes that Sync is broken,
# because from where they stand it is.
#
# So every collection the shop publishes is read, and nothing is guessed from
# a collection's name. parse_title() already refuses anything that is not an
# Asian-English card code, so the other games and the sealed product cost a
# regex each and are dropped. Being generous about what we read is safe;
# being clever about which shelf to read is what broke, twice.
#
# ---- why not just read /products.json and be done ----
# Because it lies at depth. Paging the whole-shop feed returns 250 products a
# page and keeps answering long past the end of the catalogue: Players Club
# served 25,000 rows that way against a sitemap holding nearer 11,000, with
# whole sets - ALIN, BN01, CR03 through CR10 - never appearing once. Deep
# page-based pagination repeats some products and skips others. A collection
# is small enough that its paging stays shallow and honest, so collections are
# the unit. The whole-shop feed is still swept at the end, to catch anything
# filed in no collection at all; a product seen twice is dropped by id.
my $UA   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';
my $SHOP = 'https://tcg-corner.com';
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

# ---- a refusal is not an empty shelf ----
# Reading every collection in a row gets you rate-limited; Players Club
# starts answering 429 with an HTML error page at about the thousandth
# request. Treating an undecodable body the same way as an empty one means
# the run finishes, reports success, and has quietly lost every set it could
# not read - which is the one failure this project refuses to ship. So a
# failed fetch is retried with a widening pause, and a feed that still will
# not answer exits the script non-zero rather than writing a short file.
my $FAILED = 0;
sub fetch_json {
  my $url = shift;
  my @wait = (5, 15, 30, 60, 90);
  for my $try (0 .. $#wait + 1) {
    my $body = `curl -s -m 60 -A "$UA" "$url"`;
    my $j = eval { JSON::PP->new->utf8->decode($body) };
    return $j if $j;
    last if $try > $#wait;
    printf "\n    no JSON (likely 429) - waiting %ds and retrying\n    ", $wait[$try];
    sleep $wait[$try];
  }
  $FAILED++;
  return undef;
}

# Every collection the shop publishes that actually holds something. The empty
# ones are skipped on their own say-so (products_count), which is the one piece
# of filtering the shop itself can be trusted about.
sub collections {
  my (@out, %seen);
  for my $page (1 .. 20) {
    my $j = fetch_json("$SHOP/collections.json?limit=250&page=$page") or last;
    my $c = $j->{collections} || [];
    last unless @$c;
    for my $x (@$c) {
      my $h = $x->{handle} // next;
      next unless ( $x->{products_count} // 0 ) > 0;
      next if $seen{$h}++;
      push @out, $h;
    }
    last if @$c < 250;
  }
  return @out;
}

my (@rows, %seen_id, $skipped, $sealed, $dup);
$skipped = 0; $sealed = 0; $dup = 0;

# One page of products.json, whichever feed it came from.
sub ingest {
  my $products = shift;
  for my $p (@$products) {
    # Collections overlap - a card sits in the general singles shelf and in
    # its own set's collection - so the same listing arrives more than once.
    # Dropped by product id rather than by content, because a shop really
    # does list one printing twice at two prices and those are two listings,
    # not a duplicate; indexPrices() already picks between them at runtime.
    if ( defined $p->{id} && $seen_id{ $p->{id} }++ ) { $dup++; next }
    my $t = parse_title($p->{title});
    unless ($t) { $skipped++; next }
    # Card numbers start at 001. A listing numbered 000 is the sealed product
    # - "CR13-AE000 Creation Pack 13 Booster Box" - and it is not a printing:
    # baked as one it becomes a phantom card in the set, counted towards
    # completion and priced at the cost of a whole box.
    if ($t->{code} =~ /-AE[SC]?000$/) { $sealed++; next }
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
}

# Page through one products.json feed until it runs out.
sub walk {
  my ($base, $cap) = @_;
  for my $page (1 .. $cap) {
    my $j = fetch_json("$base?limit=250&page=$page") or last;
    my $products = $j->{products} || [];
    last unless @$products;
    ingest($products);
    last if @$products < 250;
    sleep 1;                    # only where a feed is actually deep
  }
}

my @colls = collections();
printf "%d collections with stock\n\n", scalar @colls;
my $i = 0;
for my $h (@colls) {
  $i++;
  my $before = scalar @rows;
  walk("$SHOP/collections/$h/products.json", 40);
  printf "%4d/%-4d %-50s %5d rows (+%d)\n",
    $i, scalar @colls, substr($h, 0, 50), scalar @rows, scalar(@rows) - $before;
  sleep 1;          # this shop has not throttled us, and will not start now
}

# and anything filed in no collection at all
printf "\nsweeping the whole-shop feed for anything uncollected\n";
my $before_sweep = scalar @rows;
walk("$SHOP/products.json", 200);
printf "  +%d\n", scalar(@rows) - $before_sweep;

unless (@rows) { die "nothing harvested - does $SHOP still answer?\n" }

# A partial read is the dangerous outcome, not an obvious one: the file is
# well formed and simply missing sets. Nothing is written unless every feed
# answered.
if ($FAILED) {
  die sprintf "%d feed(s) could not be read even after retrying - refusing to "
            . "write a short file. Run it again when the shop stops throttling.\n",
            $FAILED;
}

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
printf "%d sealed products skipped (numbered 000)\n", $sealed if $sealed;
printf "%d repeat listings dropped (same product in several collections)\n", $dup if $dup;

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
