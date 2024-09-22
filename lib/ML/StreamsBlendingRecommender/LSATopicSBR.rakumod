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
    has %!stemRules;

    method setStemRules(%arg) {
        %!stemRules = %arg;
        self
    }

    method takeStemRules() {
        %!stemRules
    }

    ##========================================================
    ## Ingest a LSA matrix CSV file
    ##========================================================
    #| Ingest LSA matrix CSV file.
    #| * C<$fileName> CSV file name.
    #| * C<$topicColumnName> The topics column name.
    #| * C<$wordColumnName> The words column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$make> Should the inverse indexes be made or not?
    #| * C<$naive-parsing> Should the CSV file be parsed with naive assumptions or not?
    #| * C<$sep> Fields separator within a record.
    #| * C<$object> Should the result be an object or not?
    method ingest-lsa-matrix-csv-file(Str $fileName,
                                      Str :$topicColumnName = 'Topic',
                                      Str :$wordColumnName = 'Word',
                                      Str :$weightColumnName = 'Weight',
                                      Bool :$make = False,
                                      Bool :$naive-parsing = False,
                                      Str :$sep = ',',
                                      Bool :$object = True) {

        @.SMRMatrix = self.ingest-csv-file($fileName, %(Topic => $topicColumnName, Word => $wordColumnName,
                                                        Weight => $weightColumnName), :$naive-parsing, :$sep);
        if not so @.SMRMatrix { return Nil; }

        @.SMRMatrix =
                do for @.SMRMatrix -> %row {
                    { Item => %row{$topicColumnName}, TagType => 'Word', Value => %row{$wordColumnName}, Weight => %row{$weightColumnName} }
                };

        self.make-tag-inverse-indexes() when $make;

        if $object { self } else { True }
    }
    #| A modified version of C<CoreSBR::ingest-smr-marrix-csv-file>.

    ##========================================================
    ## Ingest terms global weights
    ##========================================================
    #| Global weights CSV file ingestion.
    #| * C<$fileName> CSV file name.
    #| * C<$wordColumnName> The words column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$object> Should the result be an object or not?
    method ingest-global-weights-csv-file(Str $fileName,
                                          Str :$wordColumnName = 'Word',
                                          Str :$weightColumnName = 'Weight',
                                          Bool :$object = True) {

        my $csv = Text::CSV.new;
        my @global-weights = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($wordColumnName, $weightColumnName);

        if (@global-weights[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested global weights CSV file does not have the expected column names:', @expectedColumnNames
                    .join(', '), '.';
            return Nil
        }

        self.set-global-weights(@global-weights.map({ $_{$wordColumnName} => +$_{$weightColumnName} }).Hash);

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
    method ingest-stem-rules-csv-file(Str $fileName,
                                      Str :$wordColumnName = 'Word',
                                      Str :$stemColumnName = 'Stem',
                                      Bool :$object = True) {

        my $csv = Text::CSV.new;
        my @stemRules = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($wordColumnName, $stemColumnName);

        if (@stemRules[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested stem rules CSV file does not have the expected column names:', @expectedColumnNames
                    .join(', '), '.';
            return Nil
        }

        %!stemRules = @stemRules.map({ $_{$wordColumnName} => $_{$stemColumnName} });

        if $object { self } else { True }
    }

    ##========================================================
    ## Represent by terms
    ##========================================================
    #| Represent text by terms.
    #| * C<$text> Text.
    #| * C<$splitPattern> Text splitting argument of split: a string, a regex, or a list of strings or regexes.
    #| * C<$object> Should the result be an object or not?
    method represent-by-terms(Str:D $text, :$splitPattern = /\s+/, Bool :$object = True) {

        ## Make a bag words
        my %bag = Bag($text.split($splitPattern).map({ $_.lc }));

        ## Stem the words
        if %!stemRules.elems > 0 {
            %bag = do for %bag.kv -> $word, $count {
                if %!stemRules{$word}:exists { %!stemRules{$word} => $count } else { $word => $count }
            }
        }

        ## Apply global weights
        if self.take-global-weights.elems > 0 {
            %bag = do for %bag.kv -> $word, $count {
                if self.take-global-weights{$word}:exists { $word => $count * self.take-global-weights{$word} }
            }
        }

        ## Normalize
        %bag = self.normalize(%bag, 'euclidean');

        ## Result
        self.set-value(%bag);
        if $object { self } else { %bag }
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
    method represent-by-topics(Str:D $text, Int:D $nrecs = 12, :$splitPattern = /\s+/, Bool :$normalize = False,
                               Bool :$object = True, Bool :$warn = True) {

        ## Get representation by terms
        my %bag = self.represent-by-terms($text, :$splitPattern):!object;

        ## Recommend by profile
        my %res = self.recommend-by-profile(%bag.Mix, $nrecs, :$warn):!object:!normalize;

        ## Normalize
        if $normalize {
            %res = self.normalize(%res, 'max-norm')
        } else {
            %res = self.normalize(%res, 'euclidean')
        }

        ## Result
        self.set-value(%bag);
        if $object { self } else { %res }
    }
    #| Uses C<LSATopicSBR::represent-by-terms>.

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
    method recommend-by-text(Str:D $text, Int:D $nrecs = 12, :$splitPattern = /\s+/, Bool :$normalize = False,
                             Bool :$object = True, Bool :$warn = True) {
        self.represent-by-topics($text, $nrecs, :$splitPattern, :$normalize, :object, :$warn);
        self.set-value(self.take-value().grep({ $_.value > 0 }).Array);
        ## Result
        if $object { self } else { self.take-value }
    }
    #| Uses C<LSATopicsSBR::represent-by-topics> and returns the topics with positive scores.

}
