use strict; use warnings;
use JSON::PP; use URI::Escape;
binmode(STDOUT,':encoding(UTF-8)');
my $UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';

my %want;
{ open my $P,'<:encoding(UTF-8)','/tmp/jp_sets.tsv' or die $!;
  while(my $l=<$P>){ chomp $l; my ($p)=split /\t/,$l; $want{$p}=1 if $p } close $P; }

my (@titles,$cont);
for my $page (1..30){
  my $u='https://yugipedia.com/api.php?action=query&list=allpages&apnamespace=3006&aplimit=500&format=json';
  $u .= '&apcontinue='.uri_escape_utf8($cont) if defined $cont;
  my $j=eval{ JSON::PP->new->utf8->decode(`curl -s -m 60 -A "$UA" "$u"`) } or last;
  push @titles, grep { /\(OCG-JP\)$/ } map { $_->{title} } @{$j->{query}{allpages}||[]};
  $cont = $j->{continue}{apcontinue} // $j->{'query-continue'}{allpages}{apcontinue};
  last unless defined $cont;
}
printf "OCG-JP set lists: %d\n",scalar @titles;

# yugipedia set lines carry wiki cruft after a // and the odd disambiguator
sub clean {
  my $s=shift;
  $s =~ s{\s*//.*$}{};                       # // description:: , // @Volume:: , // force-SMW
  $s =~ s{\s*\((?:card|anime|manga|Duel Links|Rush Duel)\)\s*$}{}i;
  $s =~ s{\[\[[^|\]]*\|([^\]]*)\]\]}{$1}g;   # piped wiki links
  $s =~ s{\[\[([^\]]*)\]\]}{$1}g;
  $s =~ s{['"]{2,}}{}g;                      # wiki bold/italic
  $s =~ s/\s+/ /g; $s =~ s/^\s+|\s+$//g;
  $s;
}
my (%rows,%at,$merged);
for(my $i=0;$i<@titles;$i+=40){
  my @batch=@titles[$i..($i+39>$#titles?$#titles:$i+39)];
  my $u='https://yugipedia.com/api.php?action=query&prop=revisions&rvprop=content&format=json&titles='
       .uri_escape_utf8(join('|',@batch));
  my $j=eval{ JSON::PP->new->utf8->decode(`curl -s -m 90 -A "$UA" "$u"`) } or next;
  for my $pg (values %{$j->{query}{pages}||{}}){
    my $txt=$pg->{revisions}[0]{'*'} // next;
    for my $line (split /\n/,$txt){
      next unless $line =~ /^\s*([A-Z0-9]{2,6})-JP([0-9A-Z]{3})\s*;/;
      my ($pre,$num)=($1,$2);
      next unless $want{$pre};
      my @f = split /\s*;\s*/, $line;
      my $name = clean($f[1]//''); next unless length $name;
      my $rars = clean($f[2]//'');
      # The same code appears on several set-list pages - a set and its bonus
      # pack, a reprint listing - and each names only the rarities it covers.
      # Keeping the first and dropping the rest threw real rarities away:
      # INFO-JP006 kept the bonus pack's two and lost the main set's Ultimate
      # and Secret. Merge them instead.
      my $key="$pre$num";
      if(exists $at{$key}){
        my $row=$at{$key}; $merged++;
        my %have = map { $_ => 1 } grep { length } split /\s*,\s*/, $row->[2];
        for my $r (grep { length } split /\s*,\s*/, $rars){
          next if $have{$r}++;
          $row->[2] = length($row->[2]) ? $row->[2].', '.$r : $r;
        }
        next;
      }
      my $row=[$num,$name,$rars];
      $at{$key}=$row;
      push @{$rows{$pre}}, $row;
    }
  }
}
my $n=0; $n += scalar @{$rows{$_}} for keys %rows;
printf "sets %d   printings %d   (merged %d repeat listings)
",scalar keys %rows,$n,$merged//0;
open my $O,'>:encoding(UTF-8)','/tmp/jp_cat.json' or die $!;
print $O JSON::PP->new->utf8(0)->canonical->encode(\%rows); close $O;
printf "wrote /tmp/jp_cat.json (%.1f KB)\n",(-s '/tmp/jp_cat.json')/1024;
