use WWW::Wikipedia;
use Data::Dumper;

sub println { print "@_"."\n" }

my $wiki = WWW::Wikipedia->new();

println "Please enter a question beginning with 'Who', 'What', 'When', or 'Where'";
while(1){
    print "> ";
    my $input = <>;
    chomp $input;
    $input =~ s/\?$//; # Remove question mark if the user included one
    
    # Exit condition
    if($input =~ /^[Ee]xit$/){ last; }
    # Make sure input is formatted correctly
    elsif(!($input =~ /^[Ww](ho|hat|hen|here)\s+/)){ println "Please begin your input with a 'Who', 'What', 'When', or 'Where'"; next; }

    my @split = ($input =~ /^([Ww](?:ho|hat|hen|here)\s+\w+)\s+(.*)/);
    
    # Search Wikipedia for the subject
    my @reducedSubject = testSubjectValid($split[1]);
    if($reducedSubject[0] == -1){
        println "I'm sorry, I can't find the answer to that question, feel free to try rephrasing it or asking another"; next;
    }

    # Form an array with 3 elements:
    #   [0] - Question type ('who is', 'when did', etc..)
    #   [1] - Subject of question found by testSubjectValid()
    #   [2] - Rest of query after the subject (or -1 if N/A)
    my @question = ($split[0], $reducedSubject[0], $reducedSubject[1]);

    println "C".$question[1];
}

# Finds the subject of a query by recursively removing the last
# word until it finds a substring that has a Wikipedia page
# Input: The user's query minus the question type
#   - Optional: the substring that has been removed from the end so far, 
#       compounds as the recursive calls continue and gets returned
#       at the end (see #2 in Returns)
# Returns 3 items if a Wiki page is found (or (-1 -1 -1) if not):
#   - The substring of the query that successfully
#       retrieved a Wiki page
#   - The rest of the query
#   - The summary text of the Wiki page
# Ex: If user gives input "When was George Washington born",
#       input to function will be "George Washington born", and the
#       function will recurse down to find the "George Washington" page,
#       then return ["George Washington", *wiki page summary*]
sub testSubjectValid {
    my $subject = $_[0];
    my $ongoing = $_[1];
    println "A".$subject."A";
    println "A".$ongoing."A";
    if(my $result = $wiki->search($subject)){
        println "RETURNING |".$subject."|"."$ongoing"."|";
        return ($subject, $ongoing, $result->text());
    }
    else {
        if(my @temp = ($subject =~ /(.*)\s+(\w+)/)){
            println "\tB".$temp[0];
            println "\tB".$temp[1];
            return testSubjectValid($temp[0], $temp[1]." ".$ongoing);
        }
        else{
            return (-1, -1, -1);
        }
    }
}