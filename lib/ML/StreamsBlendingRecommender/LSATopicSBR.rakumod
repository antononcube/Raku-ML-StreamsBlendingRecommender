use v6;

use Text::CSV;
use ML::StreamsBlendingRecommender::CoreSBR;
use ML::StreamsBlendingRecommender::UtilityFunctions;

## Monadic-like definition.
class ML::StreamsBlendingRecommender::LSATopicSBR
        is ML::StreamsBlendingRecommender::CoreSBR
        does ML::StreamsBlendingRecommender::UtilityFunctions {

    ##========================================================
    ## Data members
    ##========================================================
    has %.GlobalWeights is rw;
    has %.StemRules is rw;

    ##========================================================
    ## Ingest a LSA matrix CSV file
    ##========================================================
    #| Ingest LSA matrix CSV file.
    #| * C<$fileName> CSV file name.
    #| * C<$topicColumnName> The topics column name.
    #| * C<$wordColumnName> The words column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$make> Should the inverse indexes be made or not?
    #| * C<$object> Should the result be an object or not?
    method ingestLSAMatrixCSVFile(Str $fileName,
                                  Str :$topicColumnName = 'Topic',
                                  Str :$wordColumnName = 'Word',
                                  Str :$weightColumnName = 'Weight',
                                  Bool :$make = False,
                                  Bool :$naive-parsing = False,
                                  Str :$sep = ',',
                                  Bool :$object = True) {

        @.SMRMatrix = self.ingestCSVFile($fileName, %(Topic => $topicColumnName, Word => $wordColumnName, Weight => $weightColumnName), :$naive-parsing, :$sep);
        if not so @.SMRMatrix { return Nil; }

        @.SMRMatrix =
                do for @.SMRMatrix -> %row {
                    {Item => %row{$topicColumnName}, TagType => 'Word', Value => %row{$wordColumnName}, Weight => %row{$weightColumnName}}
                };

        self.makeTagInverseIndexes() when $make;

        if $object { self } else { True }
    }
    #| A modified version of C<CoreSBR::ingestSMRMatrixCSVFile>.

    ##========================================================
    ## Ingest terms global weights
    ##========================================================
    #| Global weights CSV file ingestion.
    #| * C<$fileName> CSV file name.
    #| * C<$wordColumnName> The words column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$object> Should the result be an object or not?
    method ingestGlobalWeightsCSVFile(Str $fileName,
                                      Str :$wordColumnName = 'Word',
                                      Str :$weightColumnName = 'Weight',
                                      Bool :$object = True) {

        my $csv = Text::CSV.new;
        my @globalWeights = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($wordColumnName, $weightColumnName);

        if (@globalWeights[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested global weights CSV file does not have the expected column names:', @expectedColumnNames.join(', '), '.';
            return Nil
        }

        %!GlobalWeights = @globalWeights.map({ $_{$wordColumnName} => $_{$weightColumnName} });

        if $object { self } else { True }
    }

    ##========================================================
    ## Ingest stemming rules
    ##========================================================
    #| Stemming rules CSV file ingestion.
    #| * C<$fileName> CSV file name.
    #| * C<$wordColumnName> The words column name.
    #| * C<$stemColumnName> The stems column name.
    #| * C<$object> Should the result be an object or not?
    method ingestStemRulesCSVFile(Str $fileName,
                                  Str :$wordColumnName = 'Word',
                                  Str :$stemColumnName = 'Stem',
                                  Bool :$object = True) {

        my $csv = Text::CSV.new;
        my @stemRules = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($wordColumnName, $stemColumnName);

        if (@stemRules[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested stem rules CSV file does not have the expected column names:', @expectedColumnNames.join(', '), '.';
            return Nil
        }

        %!StemRules = @stemRules.map({ $_{$wordColumnName} => $_{$stemColumnName} });

        if $object { self } else { True }
    }

    ##========================================================
    ## Represent by terms
    ##========================================================
    #| Represent text by terms.
    #| * C<$text> Text.
    #| * C<$splitPattern> Text splitting argument of split: a string, a regex, or a list of strings or regexes.
    #| * C<$object> Should the result be an object or not?
    method representByTerms( Str:D $text, :$splitPattern = /\s+/, Bool :$object = True ) {

        ## Make a bag words
        my %bag = Bag( $text.split($splitPattern).map({ $_.lc}) );

        ## Stem the words
        if %!StemRules.elems > 0 {
            %bag = do for %bag.kv -> $word, $count {
                if %!StemRules{$word}:exists { %!StemRules{$word} => $count } else { $word => $count }
            }
        }

        ## Apply global weights
        if %!GlobalWeights.elems > 0 {
            %bag = do for %bag.kv -> $word, $count {
                if %!GlobalWeights{$word}:exists { $word => $count * %!GlobalWeights{$word} }
            }
        }

        ## Normalize
        %bag = self.normalize( %bag, 'euclidean');

        ## Result
        if $object { self.value = %bag; self } else { %bag }
    }

    ##========================================================
    ## Represent by topics
    ##========================================================
    #| Represent a text query by topics.
    #| * C<$text> Text query.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$splitPattern> Text splitting argument of split: a string, a regex, or a list of strings or regexes.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    method representByTopics( Str:D $text, Int:D $nrecs = 12, :$splitPattern = /\s+/, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {

        ## Get representation by terms
        my %bag = self.representByTerms( $text, :$splitPattern):!object;

        ## Recommend by profile
        my %res = self.recommendByProfile( %bag.Mix, $nrecs, :$warn):!object:!normalize;

        ## Normalize
        if $normalize {
            %res = self.normalize( %res, 'max-norm' )
        } else {
            %res = self.normalize( %res, 'euclidean' )
        }

        ## Result
        if $object { self.setValue(%res); self } else { %res }
    }
    #| Uses C<LSATopicSBR::representByTerms>.

    ##========================================================
    ## Recommend by free text
    ##========================================================
    #| Recommend topics for a text query.
    #| * C<$text> Text query.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$splitPattern> Text splitting argument of split: a string, a regex, or a list of strings or regexes.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    method recommendByText( Str:D $text, Int:D $nrecs = 12, :$splitPattern = /\s+/, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.representByTopics( $text, $nrecs, :$splitPattern, :$normalize, :object, :$warn);
        self.setValue( self.takeValue().grep({ $_.value > 0 }).Array );
        ## Result
        if $object { self } else { self.takeValue }
    }
    #| Uses C<LSATopicsSBR::representByTopics> and returns the topics with positive scores.

}
