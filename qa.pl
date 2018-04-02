use WWW::Wikipedia;
use Data::Dumper;

sub println { print "@_"."\n" }

my $wiki = WWW::Wikipedia->new();

# if(my $result = $wiki->search('pikachu')){
#     print $result->text();
# }
# else{
#     print $wiki->error();
# }

println "Please enter a question beginning with 'Who', 'What', 'When', or 'Where'";
while(1){
    print "> ";
    my $query = <>;
    chomp $query;
    $query =~ s/\?$//;
    
    if($query =~ /^[Ee]xit$/){ last; }
    elsif(!($query =~ /^[Ww](ho|hat|hen|here)\s+/)){ println "Please begin your query with a 'Who', 'What', 'When', or 'Where'"; next; }

    $query =~ s/^([Ww].*)\s+(.*?)/\1/;

    println $query;
}