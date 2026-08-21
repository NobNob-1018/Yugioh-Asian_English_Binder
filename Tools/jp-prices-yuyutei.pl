use strict; use warnings;
binmode(STDOUT,':encoding(UTF-8)');
my $UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';

open my $P,'<:encoding(UTF-8)','/tmp/jp_sets.tsv' or die "prefixes: $!\n";
my @pre;
while(<$P>){ chomp; my ($p,$ts)=split /\t/; push @pre,[$p,$ts] if $p }
close $P;
printf "%d prefixes to try\n",scalar @pre;

open my $OUT,'>:encoding(UTF-8)','/tmp/yt_rows.tsv' or die $!;
my ($stocked,$empty,$rows)=(0,0,0);
my $i=0;
for my $e (@pre){
  my ($pre,$ts)=@$e; $i++;
  my $slug=lc $pre;
  my $html=`curl -s -m 45 -A "$UA" "https://yuyu-tei.jp/sell/ygo/s/$slug"`;
  # a set they do not carry still returns a page, so the set's own codes are
  # the only reliable proof that this is really its listing
  unless($html =~ /\Q$pre\E-JP/){ $empty++; next }
  $stocked++;

  # walk the document: rarity headings introduce the block that follows
  my $rar='';
  my $n=0;
  while($html =~ m{(?:me-2\s+text-white\s+fw-bold">([A-Z]{1,5})<)|(?:border\s+border-dark[^>]*>\s*([A-Z0-9]{2,6}-JP[0-9A-Z]{3})\s*<)}g){
    if(defined $1){ $rar=$1; next }
    my $code=$2;
    my $tail=substr($html,pos($html),1400);
    my ($name)=$tail=~m{<h4[^>]*>\s*(.*?)\s*</h4>}s;
    my ($yen) =$tail=~m{<strong[^>]*>\s*([0-9,]+)\s*円}s;
    my ($qty) =$tail=~m{在庫\s*:\s*([0-9]+)\s*点}s;
    next unless defined $yen;
    $name //= ''; $name =~ s/\s+/ /g; $name =~ s/[\t\n]//g;
    (my $price=$yen) =~ s/,//g;
    print $OUT join("\t",$code,$rar,$price,($qty//0),$name),"\n";
    $n++; $rows++;
  }
  printf "  %3d/%d  %-6s %4d rows\n",$i,scalar @pre,$pre,$n if $n;
}
close $OUT;
printf "\nstocked sets %d   not carried %d   priced rows %d\n",$stocked,$empty,$rows;
printf "wrote /tmp/yt_rows.tsv (%.1f KB)\n",(-s '/tmp/yt_rows.tsv')/1024;
