# Assignment 6
# CMSC 416
# Due: Mon Apr. 30, 2018
# Program Summary:
#   A question-answer system designed to answer simple 'who', 'what', 'when',
#   and 'where' questions, with some cool improvements over the last one.
# Algorithm:
#   When the user enters a question, it goes to Wikipedia and attempts to find
#   the related page, then uses handmade query reformulation rules to find
#   the answer.
# Usage Format:
#   perl qa.pl log.txt

use WWW::Wikipedia;
use Data::Dumper;
use Text::Autoformat qw(autoformat);
use IO::Handle;
use WordNet::QueryData;
use WordNet::stem;

if(scalar @ARGV < 1){
    die 'Please provide an output file for the log';
}

my $logFile = shift @ARGV;
my $fh;

sub println { print "@_"."\n" }
sub LOG { print $fh  "@_"."\n" }

my $wiki = WWW::Wikipedia->new();
my $wordNet = WordNet::QueryData->new();
my $stemmer = WordNet::stem->new($wordNet);

if(open($fh, '>:encoding(UTF-8)', $logFile)){
    println "This is a QA system by Bobby Best. Enter a quesion beginning with 'Who', 'What', 'When', or 'Where', or enter 'exit' to quit the program";
    while(1){
        print "> ";
        my $input = <>;
        chomp $input;
        $input = lc($input);
        $input =~ s/\?$//; # Remove question mark if the user included one
        
        if($input =~ /^\s*[Ee]xit|[Qq]uit\s*$/){ last; }
        elsif(!($input =~ /^[Ww]h(o|at|en|ere)\s+/)){ println "Please begin your input with a 'Who', 'What', 'When', or 'Where'"; next; }
        
        LOG "-----------------------------------------------------------------------------------------------";
        LOG "-----------------------------------------------------------------------------------------------";
        LOG "-----------------------------------------------------------------------------------------------";
        LOG "USER QUERY: '$input'";

        # Split user's query into:
        #   - Interrogative ("who", "what", etc..)
        #   - Verb ('is', 'was', etc.)
        #   - Article ('the', 'a', 'an') - THIS ONE IS OPTIONAL
        #   - And the actual question (i.e. everything else)
        my ($interrogative, $verb, $article, $question) = ($input =~ /^([Ww]h(?:o|at|en|ere))\s+(\w+)\s+(?:(the|a|an)\s+)?(.*)/);
        
        # Search Wikipedia for the subject, see findSubject() method for details on return values
        my ($subject, $remainder, $wikiEntry) = findSubject($question);
        if($subject == -1){
            LOG "ERROR: Unable to find a Wikipedia page";
            $fh->flush();
            println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
        }

        # Log the query breakdown
        LOG "\t- INTERROGATIVE: '$interrogative'";
        LOG "\t- VERB: '$verb'";
        if($article ne ""){
            LOG "\t- ARTICLE: '$article'";
        }
        LOG "\t- SUBJECT: '$subject'";
        if($remainder ne ""){
            LOG "\t- REMAINDER: '$remainder'";
        }
        
        # Remove unnecessary junk from the Wikipedia entry and make it easier to
        $wikiEntry =~ s/<\n?!\n?-\n?-.*?-\n?-\n?>/ /sg;
        $wikiEntry =~ s/\s?\(.*?\)\s?/ /sg;
        $wikiEntry =~ s/\{\{.*?\}\}//sg;
        $wikiEntry =~ s/\{.*?\}//sg;
        $wikiEntry =~ s/<ref.*?\/(ref)?>//sg;
        $wikiEntry =~ s/\|.*?\n//sg;
        $wikiEntry =~ s/'(?!s\s)(.*?)'/\1/sg;
        $wikiEntry =~ s/,((?!\.).)*?,/ /sg;
        $wikiEntry =~ s/^\n+/\n/s;
        $wikiEntry = lc($wikiEntry);
        
        LOG "\nWIKIPEDIA ENTRY:";
        for $line (split(/\n+/, $wikiEntry)){
            LOG "\t$line";
        }

        # Match Finding
        # For each restructured query, find all sentences that contain it.
        # Log each and add it and its weight to %totalMatches
        LOG "\nQUERY REFORMULATIONS AND THEIR MATCHES:";
        my %totalMatches = ();
        for my $ref (transform($interrogative, $verb, $article, $subject, $remainder)){
            my ($transformed, $weight) = @{$ref};
            LOG "\t[weight $weight]    /$transformed/";
            my @matches = ($wikiEntry =~ /$transformed\s+.*?[\.\?!](?!\d)/sg); # Find matches
            for my $match (@matches){
                $match =~ s/\n/ /g;
                $match =~ s/(^\s+)|(\s+$)//g;
                
                my @subjectSplit = split(/\s+/, $subject);
                my @matchSplit = split(/\s+/, $match);

                # Convert @subjectSplit into hash keys to make it easy to test if an element exists
                my %subjectSplitHash = ();
                for my $token (@subjectSplit){ $subjectSplitHash{$token} = 1; }

                # If the match is missing subject words then we need to add them on
                # (e.g. 'Washington was..' instead of 'George Washington was..'
                #       or 'the Treaty was..' instead of 'the Treaty of Versailles was..')
                if(!($match =~ /^(?:(?:the|a|an)\s+)?(?:\s+)?$subject/)){
                    for(my $i = 0; $i < scalar @matchSplit; $i++){
                        if(!(exists $subjectSplitHash{$matchSplit[$i]}) && !(exists $subjectSplitHash{$matchSplit[$i+1]})){
                            $match = $subject." ".(join(" ", @matchSplit[$i..((scalar @matchSplit)-1)]));
                            last;
                        }
                    }
                }

                LOG "\t\t\t$match";
                $totalMatches{$match} += $weight;
            }
        }
        if(scalar keys %totalMatches == 0){
            LOG "\nERROR: Didn't find any matches in the Wiki text";
            $fh->flush();
            println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
        }

        # Match Filtering
        # Try to filter out matches that don't match the question type
        for(my $i = 0; $i < scalar keys %totalMatches; $i++){
            my $match = (keys %totalMatches)[$i];
            if($interrogative =~ /[Ww]ho/){

            }
            elsif($interrogative =~ /[Ww]hat/){
                
            }
            elsif($interrogative =~ /[Ww]hen/){
                # Remove matches that don't have a number
                if(!($match =~ /\d/)){
                    delete $totalMatches{$match};
                    $i--;
                    next;
                }
            }
            elsif($interrogative =~ /[Ww]here/){
                
            }
        }
        if(scalar keys %totalMatches == 0){
            LOG "\nERROR: No Wiki matches were found that answered the question";
            $fh->flush();
            println "I'm sorry, I can't find the answer to that question, feel free to try another"; next;
        }

        # Find the highest weight out of all matches
        my $highestScore = (values %totalMatches)[0];
        for $match (keys %totalMatches){
            if($totalMatches{$match} > $highestScore){
                $highestScore = $totalMatches{$match};
            }
        }

        my $response = "";
        # If we have a response with a sufficiently high weight, use it
        if($highestScore >= 5){
            # Filter the matches down to those with the highest weight
            my @possibleAnswers = map { %totalMatches{$_} == $highestScore ? $_ : () } keys %totalMatches;
            LOG "\nPOSSIBLE ANSWERS AFTER FILTERING:";
            for $answer (@possibleAnswers){
                LOG "\t$answer";
            }

            $response = $possibleAnswers[0];
        }
        else{ # Else do tiling
            my %trigrams = ();
            for my $match (keys %totalMatches){
                my @matchSplit = split(/\s+/, $match);
                for(my $i = 2; $i < scalar @matchSplit; $i++){
                    $trigrams{$matchSplit[$i-2]." ".$matchSplit[$i-1]." ".$matchSplit[$i]} += $totalMatches{$match};
                }
            }
            println Dumper(%trigrams);
            my @sortedTrigrams = sort { $trigrams{$b} <=> $trigrams{$a} } keys %trigrams;

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
                    # elsif($responseWords[0] eq $trigramW2 && $responseWords[1] eq $trigramW3){
                    #     $response = $trigramW1." ".$response;
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
        }

        # Format response to be pretty & print it to log and console
        $response =~ s/\b$subject\b/autoformat($subject, { case => 'title' })/eg;
        $response =~ s/\n//g; # For some reason that autoformat sticks in a bunch of newlines, remove them
        $response =~ s/\s+([,\.;])/\1/g;

        LOG "\nRESPONSE: $response";
        $fh->flush();
        println $response;
    }
    close $fh;
} else {
    die 'Error opening log file '.$logFile;
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
sub findSubject {
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
            return findSubject($temp[0], $temp[1]." ".$ongoing);
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
#   - Subject found by findSubject())
#   - Remainder of query (also returned from findSubject())
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
        $article = "(?:the|a|an)?\\s+";
    }
    
    if($interrogative =~ /who/){
        # Allow for Wikipedia sometimes adding in a person's middle name
        # i.e. Guy Fieri's page starts with 'Guy Ramsay Fieri'
        if(scalar @subjectSplit == 2){
            push @searches, [$article.$subjectSplit[0]."\\s+\\w+?\\s+".$subjectSplit[1]."\\s+".$verb, 3];
            if($remainder ne ""){
                push @searches, [$article.$subjectSplit[0]."\\s+\\w+?\\s+".$subjectSplit[1]."\\s+".$verb."\\s+".$remainder, 5];
            }
        }
    }
    elsif($interrogative =~ /what/){
        
    }
    elsif($interrogative =~ /when/){
        push @searches, [$remainder, 2];
        push @searches, [$stemmer->stemString($remainder), 1];
    }
    elsif($interrogative =~ /where/){
        if($verb eq "(?:is|was)" && $remainder eq ""){
            push @searches, [$article.$subject."\\s+".$verb."\\s+"."located", 3];
            push @searches, [$article.$subject."\\s+".$verb."\\s+"."in", 3];
            push @searches, [$article.$subject."\\s+".$verb."\\s+"."found in", 3];
        }
    }

    # Account for things like 'Washington was born on' instead of
    # 'George Washington was born on' by taking the last word of 
    # the subject and iteratively adding the others onto the front
    my $temp = "";
    for(my $i = (scalar @subjectSplit)-1; $i > 0; $i--){
        $temp = $subjectSplit[$i]."\\s+".$temp;
        push @searches, [$article.$temp.$verb, 3];
        if($remainder ne ""){
            push @searches, [$article.$temp.$verb."\\s+".$remainder, 5];
        }
    }

    # Account for things like 'treaty was registered' instead
    # of 'treaty of versailles was registered' by taking the
    # first word of the subject and iteratively adding the
    # rest, this is the opposite of the similar for loop above
    my $temp = "";
    for(my $i = 0; $i < (scalar @subjectSplit)-1; $i++){
        $temp = $subjectSplit[$i]."\\s+".$temp;
        push @searches, [$article.$temp.$verb, 1];
        if($remainder ne ""){
            push @searches, [$article.$temp.$verb."\\s+".$remainder, 3];
        }
    }

    # Add the basic reformulations (not dependent on interrogative)
    # e.g. 'When was George Washington born' -> 
    #           'George Washington was' AND 'George Washington was born'
    push @searches, [$article.$subject."\\s+".$verb, 3];
    if($remainder ne ""){
        push @searches, [$article.$subject."\\s+".$verb."\\s+".$remainder, 5];
    }
    
    # Add an "or"-ing of the query's important terms
    push @searches, ["(?:".$verb."|".$remainder.")", 2];

    # Same as previous, but stemmed
    push @searches, ["(?:".$stemmer->stemWord($verb)."|".$stemmer->stemWord($remainder).")", 1];
    
    @searches = sort { $b->[1] <=> $a->[1] } @searches;
    return @searches;
}