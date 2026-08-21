use strict; use warnings; use JSON::PP;
binmode(STDOUT,':encoding(UTF-8)');
use FindBin; require $FindBin::Bin.q{/jp-rarity-map.pl};
our (%RARMAP,@RKEYS);
my %rk; $rk{$RKEYS[$_]}=$_ for 0..$#RKEYS;
sub nk { my $s=lc shift; $s=~s/\s*\((?:card|archetype|series|anime|manga)\)\s*$//;
         $s=~s/[\x{2018}\x{2019}\x{201c}\x{201d}"']//g; $s=~s/\s+/ /g; $s=~s/^\s+|\s+$//g; $s }

# ---- existing shared name table ----
my $html; { local $/; open my $H,'<:encoding(UTF-8)',$FindBin::Bin.q{/../index.html} or die $!; $html=<$H>; }
my ($lit)=$html=~/const AE_NAMES=(\[.*?\]);/s or die "no AE_NAMES\n";
my $ae=JSON::PP->new->decode($lit);
my %idx; my $i=0; for(@$ae){ $idx{nk($_)}=$i++ }
my @names=@$ae; my $base=scalar @names;

# ---- catalogue ----
my $cat; { local $/; open my $C,'<:encoding(UTF-8)','/tmp/jp_cat.json' or die $!; $cat=JSON::PP->new->decode(<$C>); }
my (%sn,%sd);
{ open my $S,'<:encoding(UTF-8)','/tmp/jp_sets.tsv' or die $!;
  while(my $l=<$S>){ chomp $l; my ($p,$ts,$n)=split /\t/,$l; next unless $p;
    $sn{$p}=$n//$p; my @t=gmtime($ts); $sd{$p}=sprintf('%04d-%02d-%02d',$t[5]+1900,$t[4]+1,$t[3]); } }

# ---- prices, deduped stock-first ----
my %best;
{ open my $F,'<:encoding(UTF-8)','/tmp/yt_rows.tsv' or die $!;
  while(my $l=<$F>){ chomp $l; my ($c,$r,$p,$q)=split /\t/,$l; next unless $c && defined $p;
    $r='N' unless defined $r && length $r;
    my $key=$RARMAP{$r}//'C'; my $kk="$c\t$key";
    if(!$best{$kk} || ($q>0)>($best{$kk}[1]>0) || (($q>0)==($best{$kk}[1]>0) && $p<$best{$kk}[0])){
      $best{$kk}=[$p,$q] } } }
my %prByCode;
for my $kk (keys %best){ my ($c,$key)=split /\t/,$kk; $prByCode{$c}{$key}=1 }

# ---- JP_CAT flat: PRE|Set name|YYYY-MM-DD|num,nameIdx,rarLetters;... ----
my (@lines,$printings,$noRar);
for my $pre (sort keys %$cat){
  my @cards;
  for my $r (@{$cat->{$pre}}){
    my ($num,$name,$rars)=@$r;
    my $k=nk($name);
    unless(exists $idx{$k}){ $idx{$k}=scalar @names; push @names,$name }
    $rars='' if !defined $rars || $rars=~/::/;
    my %seen; my @kk;
    for my $w (split /\s*,\s*/,$rars){ next if $w=~/::/; my $m=$RARMAP{$w} or next;
      push @kk,$m unless $seen{$m}++ }
    # a set list without rarities still tells us what Yuyu-tei stocked
    unless(@kk){ my $pc=$prByCode{"$pre-JP$num"};
      if($pc){ @kk = grep { defined $rk{$_} } keys %$pc } }
    $noRar++ unless @kk;
    push @cards, join(',',$num,$idx{$k},join('',map { chr(65+$rk{$_}) } grep { defined $rk{$_} } @kk));
    $printings++;
  }
  push @lines, join('|',$pre,$sn{$pre}//$pre,$sd{$pre}//'',join(';',@cards));
}
my $flat=join("\n",@lines);

# ---- JP_PRICES flat: PRE|num,rarIdx,yen,qty;... ----
my %pset;
for my $kk (keys %best){ my ($c,$key)=split /\t/,$kk;
  my ($pre,$num)=$c=~/^(.+)-JP(.+)$/ or next;
  push @{$pset{$pre}}, join(',',$num,($rk{$key}//0),$best{$kk}[0],$best{$kk}[1]) }
my $prices=join("\n",map { $_.'|'.join(';',sort @{$pset{$_}}) } sort keys %pset);

my $J=JSON::PP->new->utf8(0)->canonical;
my $newNames=$J->encode([@names[$base..$#names]]);
open my $O,'>:encoding(UTF-8)','/tmp/jp_blocks.json';
print $O $J->encode({cat=>$flat,prices=>$prices,names=>[@names[$base..$#names]],
                     base=>$base,rkeys=>\@RKEYS});
close $O;
printf "sets %d  printings %d  (no rarity: %d, %.1f%%)\n",scalar @lines,$printings,$noRar,100*$noRar/$printings;
printf "priced sets %d  priced rows %d\n",scalar keys %pset,scalar keys %best;
printf "names %d -> %d  (+%d)\n",$base,scalar @names,scalar(@names)-$base;
printf "\nJP_CAT    %7.1f KB\nJP_PRICES %7.1f KB\nnames     %7.1f KB\nTOTAL     %7.1f KB raw\n",
  length($flat)/1024,length($prices)/1024,length($newNames)/1024,
  (length($flat)+length($prices)+length($newNames))/1024;
