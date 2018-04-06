use WWW::Wikipedia;
use Data::Dumper;

sub println { print "@_"."\n" }

my $wiki = WWW::Wikipedia->new();

println "Please enter a question beginning with 'Who', 'What', 'When', or 'Where'";
while(1){
    print "> ";
    my $query = <>;
    chomp $query;
    $query =~ s/\?$//; # Remove question mark if the user included one
    
    # Exit condition
    if($query =~ /^[Ee]xit$/){ last; }
    # Make sure query is formatted correctly
    elsif(!($query =~ /^[Ww](ho|hat|hen|here)\s+/)){ println "Please begin your query with a 'Who', 'What', 'When', or 'Where'"; next; }
    
    # Turn the W-word to lowercase to stop it from confusing the program later on
    $query =~ s/^W/w/;

    # Extract subject by looking for a string of capitalized words
    my $subject = ($query =~ /(([A-Z][a-z]*\s?)+)/)[0];
    chomp $subject;

    # Search Wikipedia for the subject
    if(my $result = $wiki->search($subject)){
        println $result->text();
    }
    else {
        println $wiki->error();
    }
}