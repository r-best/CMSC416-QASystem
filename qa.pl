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

    my @split = ($query =~ /^([Ww](ho|hat|hen|here)\s+\w+)\s+(.*)/);
    my $questionType = $split[0]; # "Who is", "When did", "Where is", etc.
    my $subject = $split[2]; # The rest of the query that isn't part of the question type

    # Search Wikipedia for the subject
    my $reducedSubject = testSubjectValid($subject);
    if($reducedSubject == -1){
        println "I'm sorry, I can't find the answer to that question, feel free to try rephrasing it or asking another"; next;
    }

    println $reducedSubject;
}

# Tests if the given subject has a Wikipedia page, if not it
# removes the last word and tries again recursively
# Returns the substring of the subject that successfully
# retrieved a Wiki page, or -1 if all words were removed
# from the string and no Wiki page was found
# Ex: If user gives query "When was George Washington born", 
#       input will be "George Washington born", and the 
#       method will recurse down to find the "George Washington"
#       page.
sub testSubjectValid {
    my $subject = $_[0];
    if(my $result = $wiki->search($subject)){
        return $subject;
    }
    else {
        if($subject =~ s/(.*)\s+\w+/\1/){
            return testSubjectValid($subject);
        }
        else{
            return -1;
        }
    }
}