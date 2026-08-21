use strict; use warnings;
use JSON::PP; use URI::Escape;
binmode(STDOUT,':encoding(UTF-8)');
my $UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124 Safari/537.36';
my $CUT = 1483228800;   # 2017-01-01

my %sets; my $offset=0; my $pages=0;
while(1){
  my $q='[[Japanese release date::+]]|?Japanese release date|?Japanese set and region prefix'
       .'|limit=500|offset='.$offset;
  my $url='https://yugipedia.com/api.php?action=ask&format=json&query='.uri_escape($q);
  my $raw=`curl -s -m 60 -A "$UA" "$url"`;
  my $j=eval{ JSON::PP->new->utf8->decode($raw) } or last;
  my $res=$j->{query}{results} or last;
  my $n=scalar keys %$res; last unless $n;
  for my $title (keys %$res){
    my $p=$res->{$title}{printouts} or next;
    my $d=$p->{'Japanese release date'}[0] or next;
    my $ts=$d->{timestamp}; next unless defined $ts;
    my $pre=$p->{'Japanese set and region prefix'}[0] // '';
    $pre =~ s/-JP$//;  $pre = uc $pre;
    next unless $pre =~ /^[A-Z0-9]{2,6}$/;
    # a prefix can appear on several pages; keep the earliest date
    if(!$sets{$pre} || $ts < $sets{$pre}{ts}){ $sets{$pre}={ts=>$ts,title=>$title} }
  }
  $pages++; $offset += 500;
  last unless defined $j->{'query-continue-offset'};
  last if $pages>20;
}
my @recent = grep { $sets{$_}{ts} >= $CUT } keys %sets;
my @older  = grep { $sets{$_}{ts} <  $CUT } keys %sets;
printf "prefixes with a JP date : %d  (%d api pages)\n", scalar keys %sets, $pages;
printf "  2017 onwards          : %d\n", scalar @recent;
printf "  before 2017           : %d\n", scalar @older;

my @sorted = sort { $sets{$b}{ts} <=> $sets{$a}{ts} } @recent;
print "\nnewest ten:\n";
for (@sorted[0..9]){ last unless $_;
  my @t=gmtime($sets{$_}{ts});
  printf "  %-7s %04d-%02d-%02d  %s\n",$_,$t[5]+1900,$t[4]+1,$t[3],$sets{$_}{title} }

open my $O,'>:encoding(UTF-8)','/tmp/jp_sets.tsv' or die $!;
for my $p (@sorted){ (my $t=$sets{$p}{title}) =~ s/\s*\(.*\)\s*$//; print $O join("\t",$p,$sets{$p}{ts},$t),"\n" }
close $O;
print "\nwrote /tmp/jp_prefixes.txt\n";
