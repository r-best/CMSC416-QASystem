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
    if($subject == -1){
        println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
    }
    $wikiEntry =~ s/\(.*?\)/\s/sg;
    $wikiEntry =~ s/'(.*?)'/\1/sg;

    # For each restructured query, find all sentences that contain it, 
    # and extract unigrams, bigrams, and trigrams from them
    # The three hashes are maps of ngram => array of weights
    #   Every time an ngram is found, the weight of the query transform
    #   that retrieved it is pushed onto the corresponding array
    my %unigrams, %bigrams, %trigrams;
    for my $ref (transform($questionType, $subject, $remainder)){
        my ($transformed, $weight) = @{$ref};
        my @matches = ($wikiEntry =~ /$transformed.*?[\.\?!]/sg);
        for my $match (@matches){
            my @tokens = split(/\s+/, $match);
            for(my $i = 0; $i < scalar @tokens; $i++){
                push @{$unigrams{$tokens[$i]}}, $weight;
                if($i > 0){
                    push @{$bigrams{$tokens[$i-1]." ".$tokens[$i]}}, $weight;
                }
                if($i > 1){
                    push @{$trigrams{$tokens[$i-2]." ".$tokens[$i-1]." ".$tokens[$i]}}, $weight;
                }
            }
        }
    }

    if(scalar keys %unigrams == 0 || scalar keys %bigrams == 0 || scalar keys %trigrams == 0){
        println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
    }
    
    # Take the hashes of arrays and convert the
    # arrays to averages of their contents
    averageWeights(\%unigrams);
    averageWeights(\%bigrams);
    averageWeights(\%trigrams);

    my @sortedUnigrams = sort { $unigrams{$b} <=> $unigrams{$a} } keys %unigrams;
    my @sortedBigrams = sort { $bigrams{$b} <=> $bigrams{$a} } keys %bigrams;
    my @sortedTrigrams = sort { $trigrams{$b} <=> $trigrams{$a} } keys %trigrams;

    # Tiling
    my $response = $subject;
    for my $trigram (@sortedTrigrams){
        my @responseWords = split(/\s+/, $response);
        my ($trigramW1, $trigramW2, $trigramW3) = split(/\s+/, $trigram);

        if($responseWords[(scalar @responseWords)-2] eq $trigramW1 &&
            $responseLastWord eq $trigramW2){
            $response .= " ".$trigramW3;
        }
        elsif($responseWords[(scalar @responseWords)-1] eq $trigramW1){
            $response .= " ".$trigramW2." ".$trigramW3;
        }

        if($responseWords[0] eq $trigramW2 && $responseWords[1] eq $trigramW3){
            $response = $trigramW1." ".$response;
        }
        elsif($responseWords[0] eq $trigramW3){
            $response = $trigramW1." ".$trigramW2." ".$response;
        }
    }
    println $response;
}

# Finds the subject of a query by recursively removing the last
# word until it finds a substring that has a Wikipedia page
# Input: The user's query minus the question type
#   - Optional: the substring that has been removed from the end so far, 
#       compounds as the recursive calls continue and gets returned
#       at the end (see #2 in Returns)
# Returns 3 items if a Wiki page is found (or (-1 -1 -1) if not):
#   - The substring of the query that successfully retrieved a Wiki page
#   - The rest of the query
#   - The summary text of the Wiki page
# Ex: If user gives input "When was George Washington born",
#       input to function will be "George Washington born", and the
#       function will recurse down to find the "George Washington" page,
#       then return ["George Washington", "born", *wiki page summary*]
sub testSubjectValid {
    my ($subject, $ongoing) = @_;
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
# searchable forms
# Returns an array of (reformatted query, weight) tuples, where
# weight is manually assigned based on how good I think that
# type of rewrite is, similar to the approach in the AskMSR paper
# Inputs (3):
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
    for(my $i = (scalar @subjectSplit)-1; $i >= 0; $i--){
        $temp = $subjectSplit[$i]." ".$temp;
        push @searches, [$temp.$verb." ".$remainder, (((scalar @subjectSplit)-$i)/(scalar @subjectSplit))*10];
    }
    
    return @searches;
}

# Takes as input a reference to a hash of the form key => [array of numbers]
# Modifies the hash to be of the form key => average of the original array
sub averageWeights {
    my ($hash) = @_;
    for my $key (keys %$hash){
        my $total = 0;
        for my $number (@{$hash->{$key}}){
            $total += $number;
        }
        $hash->{$key} = $total / (scalar @{$hash->{$key}});
    }
}