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

    # Split user's query into the question type ("who is", "what are", etc..) and the actual question
    my ($questionType, $question) = ($input =~ /^([Ww](?:ho|hat|hen|here)\s+\w+(?:\s+a)?)\s+(.*)/);
    
    # Search Wikipedia for the subject, see testSubjectValid() method for details on return values
    my ($subject, $remainder, $wikiEntry) = testSubjectValid($question);
    if($subject[0] == -1){
        println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
    }
    $wikiEntry =~ s/\(.*\)/\s/g;
    # println $wikiEntry;

    my @unigrams, @bigrams, @trigrams;
    for my $transformed (transform($questionType, $subject, $remainder)){
        my @matches = ($wikiEntry =~ /$transformed.*?[\.\?!]/sg);
        for my $match (@matches){
            my @tokens = split(/\s+/, $match);
            for(my $i = 0; $i < 0+@tokens; $i++){
                push @unigrams, $tokens[$i];
                if($i > 0){
                    push @bigrams, $tokens[$i-1]." ".$tokens[$i];
                }
                if($i > 1){
                    push @trigrams, $tokens[$i-2]." ".$tokens[$i-1]." ".$tokens[$i];
                }
            }
        }
    }
    println Dumper(@bigrams);
    # println substr $wikiEntry, $index;
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
    if(my $result = $wiki->search($subject)){
        $ongoing =~ s/(.*)\s+/\1/;
        return ($subject, $ongoing, $result->text());
    }
    else {
        if(my @temp = ($subject =~ /(.*)\s+(\w+)/)){
            return testSubjectValid($temp[0], $temp[1]." ".$ongoing);
        }
        else{
            return (-1, -1, -1);
        }
    }
}

# Reformats the user's query into a variety of different
# searchable forms (returns an array of them)
# Inputs:
#   - Question type ("who is", "what are", etc.)
#   - Subject found by testSubjectValid())
#   - Remainder of query (also returned from testSubjectValid())
# Ex: "When was George Washington born?" => "George Washington was born"
sub transform {
    my ($questionType, $verb) = split(/\s+/, $_[0]);
    my $subject = $_[1];
    my @subjectSplit = split(/\s+/, $subject);
    my $remainder = $_[2];

    my @searches;

    my $temp = "";
    for(my $i = (0+@subjectSplit)-1; $i >= 0; $i--){
        $temp = $subjectSplit[$i]." ".$temp;
        push @searches, $temp.$verb." ".$remainder;
    }
    
    return @searches;
}