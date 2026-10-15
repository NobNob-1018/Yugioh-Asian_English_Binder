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

# ---- guessing which shelf to read was the bug, twice ----
# First this read the collection ygoae1 and nothing else, which missed every
# set filed in a collection of its own. The fix was to read the shop's own
# collection list and take any collection whose title names an AE set - their
# convention being "1303 BPRO-AE BURST PROTOCOL".
#
# That fix was still a guess, and it missed the whole Creation Pack line. Those
# thirteen collections are titled "CR13 Creation Pack 13" - no "-AE" anywhere
# in the string - so the title test skipped all of them. CR13 released and not
# one of its singles reached the file, while the shop's search returned them
# the whole time.
#
# It fails silently and it does not look like a harvest problem. A set with no
# rows has no printing to price, no member to count and no set to list, so the
# person pressing Sync concludes Sync is broken - which, from where they stand,
# it is.
#
# So nothing is guessed any more: every collection the shop publishes is read,
# and a collection's name decides nothing. parse_title() already refuses
# anything that is not an Asian-English card code, so the other games and the
# sealed product cost a regex each and are dropped. Being generous about what
# we read is safe. Being clever about which shelf to read has now been wrong
# twice.
#
# ---- why not just read /products.json and be done ----
# Because it lies at depth. Paging the whole-shop feed here returned 25,000
# products against a sitemap holding nearer 11,000, and whole sets - ALIN,
# BN01, CR03 through CR10, DUAD, SUDA - never appeared in it once, while the
# shop's own search had them. Deep page-based pagination repeats some products
# and skips others; two runs agree with each other, so it does not even look
# unreliable. A collection is small enough that its paging stays shallow and
# honest. The whole-shop feed is still swept at the end to catch anything in
# no collection at all, and a product seen twice is dropped by id.
#
# It is about 1,200 requests. That is the price of not guessing, once a week.

# ---- a refusal is not an empty shelf ----
# Reading 1,700 collections in a row gets you rate-limited. Players Club
# starts answering 429 with an HTML error page at about the thousandth
# request, and the first version of this treated an undecodable body the same
# way it treated an empty one: end of collection, move on, zero rows. The run
# finished, reported success, and had quietly lost every set that lives in
# the general shelf - RC04, SLF1, TFTV, SDSS and five more - because ygoae1
# came 1,530th and by then nothing was being answered at all.
#
# That is the exact failure this project refuses to ship: a smaller but
# perfectly well-formed file. So a failed fetch is retried with a widening
# pause, and if it still cannot be read the script counts it and exits
# non-zero at the end rather than writing a short file.
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

# ---- the set codes to go looking for ----
# Reading all 1,709 stocked collections is the obvious way to stop guessing,
# and this shop will not have it: it starts answering 429 at about the
# thousandth request and stays cross for a long time afterwards. So the
# selection is narrowed - but by data rather than by a hunch about how they
# name things, which is what was wrong before.
#
# The codes come from the other shop's harvest, which ran minutes ago and
# therefore knows about a set that released this week, plus every set the
# baked catalogue has ever carried. A collection is read if its title or its
# handle mentions one of those codes, or says "-AE" in their usual way, or is
# the general shelf. CR13 is found because TCG Corner is already selling it,
# not because somebody taught this script the words "Creation Pack".
sub known_prefixes {
  my %p;
  if (open my $H, '<:raw', 'tcgc-prices.json') {
    local $/; my $s = <$H>; close $H;
    $p{ uc $1 } = 1 while $s =~ /"([A-Z0-9]{2,6})-AE[SC]?[0-9]{2,3}"/gi;
  }
  if (open my $H, '<:encoding(UTF-8)', 'index.html') {
    local $/; my $s = <$H>; close $H;
    if (my ($cat) = $s =~ /const AE_CAT=(\[.*?\]);/s) {
      $p{ uc $1 } = 1 while $cat =~ /\["([A-Z0-9]{2,6})",\[/g;
    }
  }
  delete $p{''};
  return \%p;
}

# Every stocked collection that mentions one of those codes, plus the general
# shelf. Empty ones are skipped on the shop's own say-so (products_count).
sub collections {
  my $pre = known_prefixes();
  printf "%d Asian-English set codes to look for\n", scalar keys %$pre;
  my (@out, %seen);
  for my $page (1 .. 20) {
    my $j = fetch_json("$SHOP/collections.json?limit=250&page=$page") or last;
    my $c = $j->{collections} || [];
    last unless @$c;
    for my $x (@$c) {
      my $h = $x->{handle} // next;
      next unless ( $x->{products_count} // 0 ) > 0;
      my $hay = ( $x->{title} // '' ) . ' ' . $h;
      my $take = ( $h eq $SEED ) || ( $hay =~ /[A-Z0-9]{2,6}-AE\b/i );
      unless ($take) {
        for my $tok ( $hay =~ /([A-Za-z0-9]{3,6})/g ) {
          if ( $pre->{ uc $tok } ) { $take = 1; last }
        }
      }
      next unless $take;
      next if $seen{$h}++;
      push @out, $h;
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

my (@rows, %seen_id, $skipped, $norar, $sealed, $dup);
$skipped = 0; $norar = 0; $sealed = 0; $dup = 0;

# One page of products.json, whichever feed it came from.
sub ingest {
  my $products = shift;
  for my $p (@$products) {
    # Collections overlap - a card sits in the general shelf and in its own
    # set's collection - so the same listing arrives more than once. Dropped
    # by product id rather than by content, because the shop really does list
    # one printing twice at two prices and those are two listings, not a
    # duplicate; pcIndex() already resolves a repeated code+rarity the right
    # way round - in stock beats cheaper, then cheaper wins.
    if ( defined $p->{id} && $seen_id{ $p->{id} }++ ) { $dup++; next }
    my $t = parse_title($p->{title});
    unless ($t) { $skipped++; next }
    # Card numbers start at 001, so a listing numbered 000 is the sealed
    # product - "CR13-AE000 Creation Pack 13 Booster Box" - and baking it as
    # a printing puts a phantom card in the set, counted towards completion
    # and priced at the cost of a whole box.
    if ($t->{code} =~ /-AE[SC]?000$/) { $sealed++; next }
    my $v = ($p->{variants} && $p->{variants}[0]) || {};
    my $price = $v->{price};
    $price = defined $price ? $price + 0 : 0;
    unless ($price > 0) { $skipped++; next }
    my $av = exists $v->{available} ? ($v->{available} ? 1 : 0) : 1;
    $norar++ unless $t->{rar};
    push @rows, [ $t->{code}, $t->{rar}, $price, $t->{name}, $av ];
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
  sleep 1;          # ~1 request a second, which is what this shop tolerates
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

my @t = localtime; my $date = sprintf '%04d-%02d-%02d', $t[5]+1900, $t[4]+1, $t[3];
open my $O, '>:raw', $OUT or die "$OUT: $!\n";
print $O JSON::PP->new->utf8->canonical->encode({ t => $date, cur => 'HKD', rows => \@rows });
close $O;

printf "\n%d prices -> %s\n", scalar @rows, $OUT;
printf "%d listings skipped (no AE code or no price)\n", $skipped if $skipped;
printf "%d sealed products skipped (numbered 000)\n", $sealed if $sealed;
printf "%d repeat listings dropped (same product in several collections)\n", $dup if $dup;
printf "%d rows carry no rarity tag - the app treats those as unmatched\n", $norar if $norar;
