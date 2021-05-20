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
    has %!GlobalWeights;
    has %!StemRules;

    ##========================================================
    ## Ingest a LSA matrix CSV file
    ##========================================================
    method ingestLSAMatrixCSVFile(Str $fileName,
                                  Str :$topicColumnName = 'Topic',
                                  Str :$wordColumnName = 'Word',
                                  Str :$weightColumnName = 'Weight',
                                  Bool :$make = False, Bool :$object = True) {

        my $csv = Text::CSV.new;
        @.SMRMatrix = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($topicColumnName, $wordColumnName, $weightColumnName);

        if (@.SMRMatrix[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested CSV file does not have the expected column names:', @expectedColumnNames.join(', '), '.';
            return Nil
        }

        @.SMRMatrix =
                do for @.SMRMatrix -> %row {
                    {Item => %row{$topicColumnName}, TagType => 'Word', Value => %row{$wordColumnName}, Weight => %row{$weightColumnName}}
                };

        self.makeTagInverseIndexes() when $make;

        if $object { self } else { True }
    }

    ##========================================================
    ## Ingest terms global weights
    ##========================================================
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
    ## Recommend by free text
    ##========================================================
    method representByTerms( Str:D $text, :$splitPattern = /\s+/ ) {

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

        ## Normalize and return as a result
        self.normalize( %bag, 'euclidean')
    }

    ##========================================================
    ## Recommend by free text
    ##========================================================
    method recommendByText( Str:D $text, Int:D $nrecs = 12, :$splitPattern = /\s+/, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {

        ## Get representation by terms
        my %bag = self.representByTerms( $text, :$splitPattern );

        ## Recommend by profile
        self.recommendByProfile( %bag.Mix, $nrecs, :$normalize, :$object, :$warn)
    }

}
