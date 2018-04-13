use WWW::Wikipedia;
use Data::Dumper;
use Text::Autoformat qw(autoformat);

sub println { print "@_"."\n" }

my $wiki = WWW::Wikipedia->new();

println "Please enter a question beginning with 'Who', 'What', 'When', or 'Where'";
while(1){
    print "> ";
    my $input = <>;
    chomp $input;
    $input =~ s/\?$//; # Remove question mark if the user included one
    
    if($input =~ /^\s*exit\s*$/){ last; }
    elsif(!($input =~ /^wh(o|at|en|ere)\s+/)){ println "Please begin your input with a 'Who', 'What', 'When', or 'Where'"; next; }

    # Split user's query into:
    #   - Interrogative ("who", "what", etc..)
    #   - Verb ('is', 'was', etc.)
    #   - Article ('the', 'a', 'an') - THIS ONE IS OPTIONAL
    #   - And the actual question (i.e. everything else)
    my ($interrogative, $verb, $article, $question) = ($input =~ /^([Ww]h(?:o|at|en|ere))\s+(\w+)\s+(?:(the|a|an)\s+)?(.*)/);
    
    # Search Wikipedia for the subject, see testSubjectValid() method for details on return values
    my ($subject, $remainder, $wikiEntry) = testSubjectValid($question);
    if($subject == -1){
        println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
    }
    
    # Remove unnecessary junk from the Wikipedia entry
    $wikiEntry =~ s/\{\{.*?\}\}//sg;
    $wikiEntry =~ s/\{.*?\}//sg;
    $wikiEntry =~ s/<ref.*?\/(ref)?>//sg;
    $wikiEntry =~ s/\s?\(.*?\)\s?/ /sg;
    $wikiEntry =~ s/'(?!s\s)(.*?)'/\1/sg;
    $wikiEntry = lc($wikiEntry);
    # println $wikiEntry;

    # For each restructured query, find all sentences that contain it, 
    # and extract unigrams, bigrams, and trigrams from them
    # The three hashes are maps of ngram => array of weights
    #   Every time an ngram is found, the weight of the query transform
    #   that retrieved it is pushed onto the corresponding array
    my %unigrams = (), %bigrams = (), %trigrams = ();
    for my $ref (transform($interrogative, $verb, $article, $subject, $remainder)){
        my ($transformed, $weight) = @{$ref};
        println $transformed;
        my @matches = ($wikiEntry =~ /$transformed.*?[\.\?!]/sg);
        for my $match (@matches){
            # println $match;
            $match =~ s/([\(\)\$\.,'`"\x{2019}\x{201c}\x{201d}%&:;])/ $1 /g; # Separate punctuation characters into their own tokens
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
    
    # Take the hashes of arrays and convert the arrays to averages of their contents
    # so that the hashes are now maps of ngram => average weight
    sumWeights(\%unigrams);
    sumWeights(\%bigrams);
    sumWeights(\%trigrams);

    my @sortedUnigrams = sort { $unigrams{$b} <=> $unigrams{$a} } keys %unigrams;
    my @sortedBigrams = sort { $bigrams{$b} <=> $bigrams{$a} } keys %bigrams;
    my @sortedTrigrams = sort { $trigrams{$b} <=> $trigrams{$a} } keys %trigrams;

    # println Dumper(%trigrams);
    
    # Tiling
    my $response = $subject;
    for my $trigram (@sortedTrigrams){
        if($trigram =~ /^$subject/){
            $response = $trigram;
            last;
        }
    }
    while(1){
        my $temp = $response;
        for(my $i = 0; $i < scalar @sortedTrigrams; $i++){
            my @responseWords = split(/\s+/, $response);
            my ($trigramW1, $trigramW2, $trigramW3) = split(/\s+/, $sortedTrigrams[$i]);

            if($responseWords[(scalar @responseWords)-2] eq $trigramW1 &&
                $responseWords[(scalar @responseWords)-1] eq $trigramW2){
                $response .= " ".$trigramW3;
            }
            # elsif($responseWords[(scalar @responseWords)-1] eq $trigramW1){
            #     $response .= " ".$trigramW2." ".$trigramW3;
            # }
            elsif($responseWords[0] eq $trigramW2 && $responseWords[1] eq $trigramW3){
                $response = $trigramW1." ".$response;
            }
            # elsif($responseWords[0] eq $trigramW3){
            #     $response = $trigramW1." ".$trigramW2." ".$response;
            # }
            else{
                next;
            }

            splice(@sortedTrigrams, $i, 1);
            $i--;
        }

        # If nothing changed this round, we're done tiling
        last if $response eq $temp;
    }
    $response =~ s/^\b$subject\b/autoformat($subject, { case => 'title' })/eg;
    $response =~ s/\n//g; # For some reason that autoformat sticks in a bunch of newlines, remove them
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
    
    if($subject eq ""){
        return (-1, -1, -1);
    }

    if(my $result = $wiki->search($subject)){
        $ongoing =~ s/(.*)\s+/\1/;
        return ($subject, $ongoing, $result->text());
    }
    else {
        if(my @temp = ($subject =~ /(.+)\s+(\w+)/)){
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
# Inputs (4):
#   - Interrogative ("who", "what", etc.)
#   - Verb ('is', 'is a', 'was', etc.)
#   - Subject found by testSubjectValid())
#   - Remainder of query (also returned from testSubjectValid())
# Ex: "When was George Washington born?" => "George Washington was born"
sub transform {
    my ($interrogative, $verb, $article, $subject, $remainder) = @_;
    my @subjectSplit = split(/\s+/, $subject);

    my @searches;

    # If verb is present tense of 'to be', add the past tense,
    # because if someone searches 'Who is George Washington' instead
    # of 'Who was George Washington' it won't get any results
    $verb =~ s/^are/(?:are|were)/;
    $verb =~ s/^is/(?:is|was)/;

    if($article ne ""){
        $article = "(?:the|a|an)? ";
    }
    
    if($interrogative =~ /who/){
        # Account for things like 'Washington was born on' instead of
        # 'George Washington was born on' by taking the last word of 
        # the subject and iteratively adding the others onto the front
        my $temp = "";
        for(my $i = (scalar @subjectSplit)-1; $i > 0; $i--){
            $temp = $subjectSplit[$i]." ".$temp;
            push @searches, [$article.$temp.$verb, 1];
            if($remainder ne ""){
                push @searches, [$article.$temp.$verb." ".$remainder, 2];
            }
        }

        # Allow for Wikipedia sometimes adding in a person's middle name
        # i.e. Guy Fieri's page starts with 'Guy Ramsay Fieri'
        if(scalar @subjectSplit == 2){
            push @searches, [$article.$subjectSplit[0]."\\s+\\w+?\\s+".$subjectSplit[1]." ".$verb." ".$remainder, 2];
        }
    }
    elsif($interrogative =~ /what/){
        
    }
    elsif($interrogative =~ /when/){
        
    }
    elsif($interrogative =~ /where/){
        
    }

    # Account for things like 'treaty was registered' instead
    # of 'treaty of versailles was registered' by taking the
    # first word of the subject and iteratively adding the
    # rest, this is the opposite of the similar for loop found
    # in the 'who' section above
    my $temp = "";
    for(my $i = 0; $i < (scalar @subjectSplit)-1; $i++){
        $temp = $subjectSplit[$i]." ".$temp;
        push @searches, [$article.$temp.$verb, 1];
        if($remainder ne ""){
            push @searches, [$article.$temp.$verb." ".$remainder, 2];
        }
    }

    # Add the basic reformulations (not dependent on interrogative)
    # e.g. 'When was George Washington born' -> 
    #           'George Washington was' AND 'George Washington was born'
    push @searches, [$article.$subject." ".$verb, 1];
    if($remainder ne ""){
        push @searches, [$article.$subject." ".$verb." ".$remainder, 1];
    }
    
    return @searches;
}

# Takes as input a reference to a hash of the form key => [array of numbers]
# Modifies the hash to be of the form key => sum of the original array
sub sumWeights {
    my ($hash) = @_;
    for my $key (keys %$hash){
        my $total = 0;
        for my $number (@{$hash->{$key}}){
            $total += $number;
        }
        $hash->{$key} = $total;
    }
}