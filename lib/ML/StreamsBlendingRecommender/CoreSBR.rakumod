use v6;

use Text::CSV;
use ML::StreamsBlendingRecommender::AbstractSBR;
use ML::StreamsBlendingRecommender::UtilityFunctions;

## Monadic-like definition.
class ML::StreamsBlendingRecommender::CoreSBR
        is ML::StreamsBlendingRecommender::AbstractSBR
        does ML::StreamsBlendingRecommender::UtilityFunctions {

    ##========================================================
    ## Data members
    ##========================================================
    has @.SMRMatrix;
    has %!itemInverseIndexes = %();
    has %!tagInverseIndexes = %();
    has %!tagTypeToTags = %();
    has %!globalWeights = %();
    has Set $!knownTags = set();
    has Set $!knownItems = set();

    ##========================================================
    ## Setters
    ##========================================================
    method setSMRMatrix(@arg) {
        @.SMRMatrix = @arg;
        self
    }
    method setItemInverseIndexes(%arg) {
        %!itemInverseIndexes = %arg;
        self
    }
    method setTagInverseIndexes(%arg) {
        %!tagInverseIndexes = %arg;
        self
    }
    method setTagTypeToTags(%arg) {
        %!tagTypeToTags = %arg;
        self
    }
    method setGlobalWeights(%arg) {
        %!globalWeights = %arg;
        self
    }
    method setKnownTags($arg) {
        $!knownTags = $arg;
        self
    }
    method setKnownItems($arg) {
        $!knownItems = $arg;
        self
    }


    ##========================================================
    ## Takers
    ##========================================================
    method takeSMRMatrix() {
        @.SMRMatrix
    }
    method takeItemInverseIndexes() {
        %!itemInverseIndexes
    }
    method takeTagInverseIndexes() {
        %!tagInverseIndexes
    }
    method takeTagTypeToTags() {
        %!tagTypeToTags
    }
    method takeGlobalWeights() {
        %!globalWeights
    }
    method takeKnownTags() {
        $!knownTags
    }
    method takeKnownItems() {
        $!knownItems
    }

    ##========================================================
    ## BUILD
    ##========================================================
    submethod BUILD(
            #:$.value
            #:@.SMRMatrix,
            :%!itemInverseIndexes,
            :%!tagInverseIndexes,
            :%!tagTypeToTags,
            :%!globalWeights,
            Set :$!knownTags,
            Set :$!knownItems){};

    ##========================================================
    ## Clone
    ##========================================================
    method clone(::?CLASS:D: --> ::?CLASS:D) {
        my ML::StreamsBlendingRecommender::CoreSBR $cloneObj =
                ML::StreamsBlendingRecommender::CoreSBR.new(
                        :@.SMRMatrix,
                        :%!itemInverseIndexes,
                        :%!tagInverseIndexes,
                        :%!tagTypeToTags,
                        :%!globalWeights,
                        :$!knownTags,
                        :$!knownItems,
                        :$.value
                        );
        say "clone:", $cloneObj.takeTagInverseIndexes().elems;
        $cloneObj
    }

    ##========================================================
    ## Ingest a SMR matrix CSV file
    ##========================================================
    #| Ingest SMR matrix CSV file ingestion.
    #| * C<$fileName> CSV file name.
    #| * C<$itemColumnName> The items column name.
    #| * C<$tagTypeColumnName> The tag types column name.
    #| * C<$valueColumnName> The values (tags) column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$make> Should the inverse indexes be made or not?
    #| * C<$object> Should the result be an object or not?
    method ingestSMRMatrixCSVFile(Str $fileName,
                                  Str :$itemColumnName = 'Item',
                                  Str :$tagTypeColumnName = 'TagType',
                                  Str :$valueColumnName = 'Value',
                                  Str :$weightColumnName = 'Weight',
                                  Bool :$make = False, Bool :$object = True) {

        my $csv = Text::CSV.new;
        @.SMRMatrix = $csv.csv(in => $fileName, headers => 'auto');

        my @expectedColumnNames = ($itemColumnName, $tagTypeColumnName, $valueColumnName, $weightColumnName);

        if (@.SMRMatrix[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested CSV file does not have the expected column names:', @expectedColumnNames.join(', '), '.';
            return Nil
        }

        @.SMRMatrix =
                do for @.SMRMatrix -> %row {
                    {Item => %row{$itemColumnName}, TagType => %row{$tagTypeColumnName}, Value => %row{$valueColumnName}, Weight => %row{$weightColumnName}}
                };

        %!itemInverseIndexes = %();
        %!tagInverseIndexes = %();

        self.makeTagInverseIndexes() when $make;

        if $object { self } else { True }
    }
    #| A modified version of this function's code is used in C<LSATopicSBR::ingestLSAMatrixCSVFile>.

    ##========================================================
    ## Make tag inverse indexes
    ##========================================================
    #| Make the inverse indexes that correspond to the SMR matrix.
    #| * C<$object> Should the result be an object or not?
    method makeTagInverseIndexes(Bool :$object = True) {

        ## Split into a hash by tag type.
        my %inverseIndexGroups = @.SMRMatrix.classify({ $_<TagType> });

        ## For each tag type split into hash by Value.
        my %inverseIndexesPerTagType = %inverseIndexGroups.pairs.map({ $_.key => $_.value.classify({ $_<Value> }) });

        ## Re-make each array of hashes into a hash.
        %inverseIndexesPerTagType =
                %inverseIndexesPerTagType.pairs.map({ $_.key => $_.value.pairs.map({ $_.key => Mix($_.value.map({ $_<Item> => $_<Weight> })) }) });

        ## Make it a hash of hashes of mixes.
        %inverseIndexesPerTagType =
                Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ Hash($_) }));

        ## Derive the tag type to tags hash map.
        %!tagTypeToTags = Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ $_.keys }));

        ## Flatten the inverse index groups.
        %!tagInverseIndexes = %();
        for %inverseIndexesPerTagType.values -> %h { %!tagInverseIndexes.append(%h) };

        ## Assign known tags.
        say (%!tagInverseIndexes.keys).Set;
        $!knownTags = (%!tagInverseIndexes.keys).Set;

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        if $object { self } else { True }
    }

    ##========================================================
    ## Transpose tag inverse indexes
    ##========================================================
    #| Transpose inverse indexes.
    #| * C<$object> Should the result be an object or not?
    method transposeTagInverseIndexes(Bool :$object = True) {

        ## Transpose tag inverse indexes into item inverse indexes.

        my $items = %!tagInverseIndexes.values>>.keys.flat.unique;

        %!itemInverseIndexes = Hash($items Z=> Mix());

        for %!tagInverseIndexes.kv -> $tag, $mix {
            for $mix.kv -> $item, $val {
                %!itemInverseIndexes{$item}.push($tag => $val)
            }
        }

        %!itemInverseIndexes = do for %!itemInverseIndexes.kv -> $item, $arr { $item => Mix($arr) };

        ## Assign known items.
        $!knownItems = Set(%!itemInverseIndexes.keys);

        if $object { self } else { True }
    }
    #| I.e. make inverse indexes that correspond to the rows of the SMR matrix.

    ##========================================================
    ## Profile
    ##========================================================
    multi method profile(@items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.profile(Mix(@items), :$normalize, :$object, :$warn)
    }

    multi method profile(Mix:D $items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {

        ## Transpose inverse indexes if needed
        if %!itemInverseIndexes.elems == 0 { self.transposeTagInverseIndexes() }

        ## Make sure items are known
        my $itemsQuery = Mix($items{($items (&) $!knownItems).keys}:p);

        if $itemsQuery.elems == 0 and $warn {
            warn 'None of the items is known in the recommender.';
            $.value = %();
            return do if $object { self } else { $.value }
        }

        if $itemsQuery.elems < $items.elems and $warn {
            warn 'Some of the items are unknown in the recommender.';
        }

        ## Compute the profile
        my %itemMix = [(+)] %!itemInverseIndexes{$itemsQuery.keys} Z<<*>> $itemsQuery.values;

        ## Normalize
        if $normalize { %itemMix = self.normalize(%itemMix, 'max-norm') }

        ## Sort
        my @res = %itemMix.sort({ -$_.value });

        ## Result
        self.value = @res;

        if $object { self } else { @res }
    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    #| Recommend items for a consumption history (that is a list or a mix of items.)
    #| * C<@items> A list or a mix of items.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend(@items, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.recommend(Mix(@items), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend(Mix:D $items, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        ## It is not fast, but it is just easy to compute the profile and call recommendByProfile.
        self.recommendByProfile(Mix(self.profile($items).takeValue), $nrecs, :$normalize, :$object, :$warn)
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    #| Recommend items for a consumption profile (that is a list or a mix of tags.)
    #| * C<@prof> A list or a mix of tags.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommendByProfile(@prof, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.recommendByProfile(Mix(@prof), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommendByProfile(Mix:D $prof, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {

        ## Make sure tags are known
        my $profQuery = Mix($prof{($prof (&) $!knownTags).keys}:p);

        if $profQuery.elems == 0 and $warn {
            warn 'None of the profile tags is known in the recommender.';
            self.value = %();
            return do if $object { self } else { self.value }
        }

        if $profQuery.elems < $prof.elems and $warn {
            warn 'Some of the profile tags are unknown in the recommender.';
        }

        ## Compute recommendations
        my %profMix = [(+)] %!tagInverseIndexes{$profQuery.keys} Z<<*>> $profQuery.values;

        ## Normalize
        if $normalize { %profMix = self.normalize(%profMix, 'max-norm') }

        ## Sort
        my @res = %profMix.sort({ -$_.value });

        ## Result
        self.value = do if $nrecs < @res.elems { @res.head($nrecs) } else { @res };

        if $object { self } else { $.value }
    }

    ##========================================================
    ## Normalize per tag type
    ##========================================================
    #| Normalize the inverse indexes per tag type.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<$object> Should the result be an object or not?
    method normalizePerTagType($normSpec, Bool :$object = True) {

        ## Find norms per tag type.
        my %norms =
                do for %!tagTypeToTags.kv -> $k, $v {
                    my @tags = $v>>.values.flat;
                    my $norm = self.norm(%!tagInverseIndexes{@tags}>>.values.flat, $normSpec);
                    $k => $norm
                };

        ## Invert tag type to tag hash.
        my %tagToTagType = %!tagTypeToTags.invert;

        ## Normalize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    my $norm = %norms{%tagToTagType{$k}};
                    $k => $v <</>> ($norm > 0 ?? $norm !! 1)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        if $object { self } else { True }
    }

    ##========================================================
    ## Normalize per tag type per item
    ##========================================================
    #| Normalize the inverse indexes per tag type per item.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<$object> Should the result be an object or not?
    method normalizePerTagTypePerItem($normSpec, Bool :$object = True) {

        ## Instead of working with combined keys (tagType item)
        ## we loop over the tag types.

        ## Loop over tag types.
        my %res = %();
        for %!tagTypeToTags.kv -> $k, $v {

            # Get the items values from the tag inverse indexes.
            my %itemValues = %();
            for %!tagInverseIndexes{|$v}.kv -> $tag, $mix {
                %itemValues.push($mix.pairs);
            }

            ## Calculate norms per item.
            my %itemNorms =
                    do for %itemValues.kv -> $item, $vals {
                        my $norm = self.norm(Array($vals), $normSpec);
                        $item => $norm > 0 ?? $norm !! 1
                    }

            ## For each tag normalize the item values.
            my %tagRes =
                    do for |$v -> $tag {
                        my %mix = %!tagInverseIndexes{$tag};
                        $tag => Mix(%mix.keys Z=> %mix.values <</>> %itemNorms{|%mix.keys})
                    }

            %res.append(%tagRes)
        }

        %!tagInverseIndexes = %res;

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        if $object { self } else { True }
    }
    #| Interpretation: each row of the SMR matrix is partitioned in tag type sub-vectors
    #| and those sub-vectors are normalized.

    ##========================================================
    ## Normalize per tag
    ##========================================================
    #| Normalize the inverse indexes per tag.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<$object> Should the result be an object or not?
    method normalizePerTag($normSpec, Bool :$object = True) {

        ## Normalize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    my $norm = self.norm($v.values, $normSpec);
                    $k => $v <</>> ($norm > 0 ?? $norm !! 1)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        if $object { self } else { True }
    }

    ##========================================================
    ## Unitize
    ##========================================================
    #| Unitize the inverse indexes.
    #| * C<$object> Should the result be an object or not?
    method unitize(Bool :$object = True) {

        ## Unitize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    $k => Mix($v.keys)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        if $object { self } else { True }
    }

    ##========================================================
    ## Global weights
    ##========================================================
    #| Compute global weights for the keys of the inverse indexes.
    #| * C<$spec> Global weight function spec; one of C<<IDF GFIDF Binary None Normal ColumnStochastic Sum>>.
    #| * C<$object> Should the result be an object or not?
    method globalWeights($spec, Bool :$object = True) {

        my %colSums = Hash(%!tagInverseIndexes.keys Z=> %!tagInverseIndexes.values>>.total);
        %colSums = %colSums.deepmap({ $_ > 0 ?? $_ !! $_ });

        my $nrows = %!tagInverseIndexes.values>>.keys.flat.unique.elems;

        ## Main switch
        given $spec {
            when 'IDF' {
                %!globalWeights = %colSums.deepmap({ log($nrows / $_) })
            }

            when 'GFIDF' {
                die "Global weights specification 'GFIDF' is not implemented."
            }

            when 'Normal' {
                %!globalWeights =
                        do for %!tagInverseIndexes.kv -> $k, $v {
                            my $norm = self.norm($v.values, 'euclidean');
                            $k => 1 <</>> ($norm > 0 ?? $norm !! 1)
                        }
            }

            when $_ (elem) <Binary None> {
                %!globalWeights = Hash(%!tagInverseIndexes.keys Z=> 1.roll(%!tagInverseIndexes.elems))
            }

            when $_ (elem) <ColumnStochastic Sum> {
                %!globalWeights = %colSums.deepmap({ 1 / $_ })
            }

            when 'Entropy' {
                die "Global weights specification 'Entropy' is not implemented."
            }

            default {
                die "Unknown global weights specification $spec."
            }
        }

        if $object { self } else { %!globalWeights }
    }

    ##========================================================
    ## Remove tag type(s)
    ##========================================================
    #| Remove tag types.
    #| * C<@tagTypes> A list of tag types to be removed
    method removeTagTypes(@tagTypes) {

        my %tagTypesToRemoveToTags = %!tagTypeToTags{@tagTypes}:p;

        if %tagTypesToRemoveToTags.elems == 0 {
            warn 'None of the specified tag types is known in the recommender.';
            return self
        }

        for %tagTypesToRemoveToTags.kv -> $tagType, $tags {
            %!tagInverseIndexes{|$tags}:delete;
            $!knownTags (-)= $tags;
        }

        %!tagTypeToTags{@tagTypes}:delete;

        self
    }
}
