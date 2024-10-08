use v6;

use Text::CSV;
use Data::Reshapers;
use Data::TypeSystem::Predicates;
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
    method set-smr-matrix(@arg) {
        @.SMRMatrix = @arg;
        self
    }
    method set-item-inverse-indexes(%arg) {
        %!itemInverseIndexes = %arg;
        self
    }
    method set-tag-inverse-indexes(%arg) {
        %!tagInverseIndexes = %arg;
        self
    }
    method set-tag-type-to-tags(%arg) {
        %!tagTypeToTags = %arg;
        self
    }
    method set-global-weights(%arg) {
        %!globalWeights = %arg;
        self
    }
    method set-known-tags($arg) {
        $!knownTags = $arg;
        self
    }
    method set-known-items($arg) {
        $!knownItems = $arg;
        self
    }


    ##========================================================
    ## Takers
    ##========================================================
    method take-smr-matrix() {
        @.SMRMatrix
    }
    method take-item-inverse-indexes() {
        %!itemInverseIndexes
    }
    method take-tag-inverse-indexes() {
        %!tagInverseIndexes
    }
    method take-tag-type-to-tags() {
        %!tagTypeToTags
    }
    method take-global-weights() {
        %!globalWeights
    }
    method take-known-tags() {
        $!knownTags
    }
    method take-known-items() {
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
            Set :$!knownItems) {};

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
                        value => self.take-value
                        );
        ## say "clone:", $cloneObj.take-tag-inverse-indexes().elems;
        $cloneObj
    }

    ##========================================================
    ## Ingest a SMR matrix CSV file
    ##========================================================
    #| Ingest SMR matrix CSV file.
    #| * C<$fileName> CSV file name.
    #| * C<$itemColumnName> The items column name.
    #| * C<$tagTypeColumnName> The tag types column name.
    #| * C<$valueColumnName> The values (tags) column name.
    #| * C<$weightColumnName> The weights column name.
    #| * C<$make> Should the inverse indexes be made or not?
    #| * C<$naive-parsing> Should the CSV file be parsed with naive assumptions or not?
    #| * C<$sep> Fields separator within a record.
    #| * C<$object> Should the result be an object or not?
    method ingest-smr-marrix-csv-file(Str $fileName,
                                      Str :$itemColumnName = 'Item',
                                      Str :$tagTypeColumnName = 'TagType',
                                      Str :$valueColumnName = 'Value',
                                      Str :$weightColumnName = 'Weight',
                                      Bool :$make = False,
                                      Bool :$naive-parsing = False,
                                      Str :$sep = ',',
                                      Bool :$object = True) {

        my $res = self.ingest-csv-file($fileName, %(Item => $itemColumnName, TagType => $tagTypeColumnName,
                                                    Value => $valueColumnName, Weight => $weightColumnName),
                :$naive-parsing, :$sep);
        if not so $res {
            return $object ?? Nil !! False;
        }

        self.set-smr-matrix($res);

        %!itemInverseIndexes = %();
        %!tagInverseIndexes = %();

        self.make-tag-inverse-indexes() when $make;

        return $object ?? self !! True;
    }
    #| A modified version of this function's code is used in C<LSATopicSBR::ingest-lsa-matrix-csv-file>.

    ##========================================================
    ## Make tag inverse indexes
    ##========================================================
    #| Make the inverse indexes that correspond to the SMR matrix.
    #| * C<$object> Should the result be an object or not?
    multi method make-tag-inverse-indexes(Bool :$object = True) {

        ## Split into a hash by tag type.
        #my %inverseIndexGroups = @.SMRMatrix.classify({ $_<TagType> });

        ## For each tag type split into hash by Value.
        #my %inverseIndexesPerTagType = %inverseIndexGroups.pairs.map({ $_.key => $_.value.classify({ $_<Value> }) });

        ## The following line does what the commented out lines above do.
        my Hash %inverseIndexesPerTagType = self.take-smr-matrix.classify({ $_<TagType Value> });

        ## Re-make each array of hashes into an item-to-weight hash.
        %inverseIndexesPerTagType =
                %inverseIndexesPerTagType.pairs.map({ $_.key => %($_.value.pairs.map({ $_.key => Mix($_.value
                        .map({ $_<Item> => $_<Weight>.subst(/'.' $/, '.0') })) })) });

        ## Make it a hash of hashes of mixes.
        %inverseIndexesPerTagType =
                Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ Hash($_) }));

        self.make-tag-inverse-indexes(%inverseIndexesPerTagType, :$object)
    }

    multi method make-tag-inverse-indexes(%inverseIndexesPerTagType, Bool :$object = True) {

        ## Derive the tag type to tags hash map.
        %!tagTypeToTags = Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ $_.keys.List })
                .List);

        ## Flatten the inverse index groups.
        %!tagInverseIndexes = %();
        for %inverseIndexesPerTagType.values -> %h { %!tagInverseIndexes.append(%h) };

        # This has to be refactored!
        # It is easier to it here as a post-process, during the .append-ing above.
        %!tagInverseIndexes = %!tagInverseIndexes.map({ $_.key => $_.value.Mix });

        ## Assign known tags.
        ## say (%!tagInverseIndexes.keys).Set;
        $!knownTags = (%!tagInverseIndexes.keys).Set;

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        return $object ?? self !! True;
    }

    ##========================================================
    ## Make from long form dataset
    ##========================================================
    #| Make inverse indexes using long form data
    #| * C<@data> A list of hashes.
    #| * C<$itemColumnName> Which column is the item column.
    #| * C<$tagTypeColumnName> Which column is the tag type column.
    #| * C<$valueColumnName> Which column is the (tag) value column.
    #| * C<$weightColumnName> Which column is the weight column.
    #| * C<$object> Should the result be an object or not?
    method make-tag-inverse-indexes-from-long-form(@data where is-array-of-hashes(@data),
                                                   Str :$itemColumnName = 'Item',
                                                   Str :$tagTypeColumnName = 'TagType',
                                                   Str :$valueColumnName = 'Value',
                                                   Str :$weightColumnName = 'Weight',
                                                   Bool :$object = True) {

        self.set-smr-matrix(@data.map({ %( Item => $_{$itemColumnName},
                                         TagType => $_{$tagTypeColumnName},
                                         Value => $_{$valueColumnName},
                                         Weight => $_{$weightColumnName}) }));

        return self.make-tag-inverse-indexes(:$object);
    }

    ##========================================================
    ## Transpose tag inverse indexes
    ##========================================================
    #| Transpose inverse indexes.
    #| * C<$object> Should the result be an object or not?
    method transpose-tag-inverse-indexes(Bool :$object = True) {

        ## WARNING! -- This function has to be refactored to use the role's transpose.

        ## Transpose tag inverse indexes into item inverse indexes.

        #my $items = %!tagInverseIndexes.values>>.keys.flat.unique.Array;

        for %!tagInverseIndexes.kv -> $tag, $mix {
            for $mix.kv -> $item, $val {
                if %!itemInverseIndexes{$item}:!exists {
                    %!itemInverseIndexes{$item} = MixHash($tag => $val)
                } else {
                    %!itemInverseIndexes{$item} (+)= Mix($tag => $val)
                }
            }
        }

        %!itemInverseIndexes = do for %!itemInverseIndexes.kv -> $item, $arr { $item => Mix($arr) };

        ## Assign known items.
        $!knownItems = Set(%!itemInverseIndexes.keys);

        return $object ?? self !! True;
    }
    #= I.e. make inverse indexes that correspond to the rows of the SMR matrix.

    ##========================================================
    ## Make from dataset
    ##========================================================
    #| Make tag inverse indexes from wide form dataset.
    #| * C<@data> A list of hashes.
    #| * C<$tagTypes> Tag types to use -- columns of the dataset.
    #| * C<$itemColumnName> Which column is the identifier column.
    #| * C<$addTagTypesToColumnNames> Should the tag types be prefixes of the tags or not?
    #| * C<$sep> Separator between the tag type prefixes and the tags.
    #| * C<$object> Should the result be an object or not?
    method make-tag-inverse-indexes-from-wide-form(@data where is-array-of-hashes(@data),
                                                   :$tagTypes = *,
                                                   Str:D :$itemColumnName = @data[0].keys[0],
                                                   Bool :$addTagTypesToColumnNames = True,
                                                   Str:D :$sep = ":",
                                                   Bool :$object = True) {

        ## Get the tag types.
        my Str:D @tagTypesLocal;

        if $tagTypes.isa(Whatever) {
            @tagTypesLocal = @data[0].keys.grep({ $_ ne $itemColumnName })
        } else {
            try {
                @tagTypesLocal = |$tagTypes;
            }

            if $! {
                note 'The argument tagTypes is expected to be a positional of strings or Whatever.';
                return $object ?? Nil !! False;
            }
        }

        ## Cross-tabulate for each tag type.
        my %matrices = do for @tagTypesLocal -> $tagType {

            ## Cross-tabulate tag-vs-item.
            my %res = Data::Reshapers::cross-tabulate(@data, $tagType, $itemColumnName);

            ## If specified add the tag type to the tag-keys.
            if $addTagTypesToColumnNames {
                %res = %res.map({ $tagType ~ $sep ~ $_.key => $_.value }).Array;
            }

            ## Make a pair
            $tagType => %(%res.map({ $_.key => Mix($_.value) }).Array)
        }

        ## Finish the tag inverse index making.
        self.make-tag-inverse-indexes(%matrices, :$object);
    }

    ##========================================================
    ## Profile
    ##========================================================
    #| Find items profile.
    #| * C<@items> A list or a mix of items.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method profile(@items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.profile(Mix(@items), :$normalize, :$object, :$warn)
    }

    multi method profile(Str $item, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {
        self.profile(Mix([$item]), :$normalize, :$object, :$warn)
    }

    multi method profile(Mix:D $items, Bool :$normalize = False, Bool :$object = True, Bool :$warn = True) {

        ## Transpose inverse indexes if needed
        if %!itemInverseIndexes.elems == 0 { self.transpose-tag-inverse-indexes() }

        ## Except the line above the code of this method is same/dual to .recommend-by-profile

        ## Make sure items are known
        my $itemsQuery = Mix($items{($items (&) $!knownItems).keys}:p);

        if $itemsQuery.elems == 0 and $warn {
            warn 'None of the items is known in the recommender.';
            self.set-value(%());
            return $object ?? self !! self.take-value();
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
        self.set-value(@res);

        return $object ?? self !! self.take-value();
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
    multi method recommend(@items, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        self.recommend(Mix(@items), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend($item, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        self.recommend(Mix([$item]), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend(Mix:D $items, Numeric:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True,
                           Bool :$warn = True) {
        ## It is not fast, but it is just easy to compute the profile and call recommend-by-profile.
        self.recommend-by-profile(Mix(self.profile($items):!object), $nrecs, :$normalize, :$object, :$warn)
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
    multi method recommend-by-profile(@prof,
                                      Numeric:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn = True) {
        self.recommend-by-profile(Mix(@prof), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend-by-profile(Str $profTag,
                                      Numeric:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn = True) {
        self.recommend-by-profile(Mix([$profTag]), $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommend-by-profile(Mix:D $prof,
                                      Numeric:D $nrecs is copy = 12,
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn = True) {

        ## Make sure tags are known
        my $profQuery = Mix($prof{($prof (&) $!knownTags).keys}:p);

        if $profQuery.elems == 0 and $warn {
            warn 'None of the profile tags is known in the recommender.';
            self.set-value(%());
            return $object ?? self !! self.take-value();
        }

        if $profQuery.elems < $prof.elems and $warn {
            warn 'Some of the profile tags are unknown in the recommender.';
        }

        $nrecs = round($nrecs);

        if $nrecs < 0 {
            warn 'The second argument is expected to be a positive integer or Inf';
            self.set-value(%());
            return $object ?? self !! self.take-value();
        }

        ## Compute recommendations
        my %profMix = [(+)] %!tagInverseIndexes{$profQuery.keys} Z<<*>> $profQuery.values;

        ## Normalize
        if $normalize { %profMix = self.normalize(%profMix, 'max-norm') }

        ## Sort
        my @res = %profMix.sort({ -$_.value }).Array;

        ## Result
        self.set-value(do if $nrecs < @res.elems { @res.head($nrecs).Array } else { @res });

        return $object ?? self !! self.take-value();
    }

    ##========================================================
    ## Filter by profile
    ##========================================================
    #| Filter items by profile
    #| * C<$prof> A profile specification used to filter with.
    #| * C<$type>  The type of filtering one of "union" or "intersection".
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method filter-by-profile(Mix:D $prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {
        return self.filter-by-profile($prof.keys, :$type, :$object, :$warn);
    }

    multi method filter-by-profile(@prof,
                                   Str :$type = 'intersection',
                                   Bool :$object = True,
                                   Bool :$warn = True) {

        my %profMix;
        if $type.lc eq 'intersection' {

            %profMix = [(&)] %!tagInverseIndexes{@prof};

        } elsif $type.lc eq 'union' {

            %profMix = [(|)] %!tagInverseIndexes{@prof};

        } else {
            warn 'The value of the type argument is expected to be one of \'intersection\' or \'union\'.' if $warn;
            self.set-value(%());
            return $object ?? self !! self.take-value();
        }

        ## Result
        self.set-value(%profMix.keys.Array);

        return $object ?? self !! self.take-value();
    }

    ##========================================================
    ## Retrieve by query elements
    ##========================================================
    sub QueryElementSpecQ($x) {
        return $x.isa(Whatever) || $x ~~ Str || $x ~~ Positional || $x ~~ Map;
    }

    sub QueryElementSpecConvert($x) {
        given $x {
            when $_ ~~ Whatever { return () }
            when $_ ~~ Str { return [$_,] }
            when $_ ~~ Hash { return $_.keys.List }
            default { return $_ }
        }
    }

    #| Retrieve by query elements.
    #| * C<$should> A profile specification used to recommend with.
    #| * C<$must> A profile specification used to filter with.
    #| The items in the result must have the tags in C<$must>.
    #| * C<$mustNot> A profile specification used to filter with.
    #| The items in the result must not have the tags in C<$mustNot>.
    #| * C<$mustType> The type of filtering with the must tags; one of "union" or "intersection".
    #| * C<$mustNotType> The type of filtering with the must not tags; one of "union" or "intersection".
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    #| The result is assigned to C<!value>.
    #| This function is based on the method C<recommend-by-profile> ("should")
    #| and C<filter-by-profile> ("must" and "must not").
    multi method retrieve-by-query-elements(Mix:D $should, $must = (), $mustNot = (),
                                            Str :$mustType = 'intersection',
                                            Str :$mustNotType = 'union',
                                            Bool :$object = True,
                                            Bool :$warn = True) {
        return self.retrieve-by-query-elements($should.keys, $must, $mustNot, :$mustType, :$mustNotType, :$object,
                :$warn);
    }

    multi method retrieve-by-query-elements(:$should = (),
                                            :$must = (),
                                            :$mustNot = (),
                                            *%args) {
        return self.retrieve-by-query-elements($should, $must, $mustNot, |%args);
    }

    multi method retrieve-by-query-elements($should is copy = Whatever,
                                            $must is copy = (),
                                            $mustNot is copy = (),
                                            Str :$mustType = 'intersection',
                                            Str :$mustNotType = 'union',
                                            Bool :$object = True,
                                            Bool :$warn = True) {

        if $should.isa(Whatever) && QueryElementSpecQ(self.take-value) {
            $should = self.take-value
        }

        $should = QueryElementSpecConvert($should);
        $must = QueryElementSpecConvert($must);
        $mustNot = QueryElementSpecConvert($mustNot);

        if $should.elems + $must.elems + $mustNot.elems == 0 {
            warn 'All query specifications are empty.' if $warn;
            self.set-value(());
            return $object ?? self !! self.take-value();
        }

        # Should
        my %shouldItems;
        my $recs;
        if $should.elems > 0 || $must.elems > 0 {
            $recs = self.recommend-by-profile([|$should, |$must], Inf, :$warn):!object;
            %shouldItems = Mix($recs);
        } else {
            %shouldItems = Mix(self.take-known-items);
        }

        my %res = %shouldItems;

        # Must
        my %mustItems;
        if $must.elems > 0 {
            %mustItems = Mix(self.filter-by-profile($must, type => $mustType, :$warn):!object);
        }

        if %mustItems.elems > 0 {
            %res = %res (&) %mustItems;
        }

        # Must Not
        my %mustNotItems;
        if $mustNot.elems > 0 {
            %mustNotItems = Mix(self.filter-by-profile($mustNot, type => $mustNotType, :$warn):!object);
        }

        if %mustNotItems.elems > 0 {
            %res = %res (-) %mustNotItems;
        }

        # Result
        if $recs.elems > 0 {
            # If profile recommendations were computed we want to use scores.
            my %profRecs = |$recs;
            self.set-value(%profRecs.grep({ $_.key ∈ %res }).sort({ -$_.value }).Array);
        } else {
            self.set-value(%res.Array);
        }

        return $object ?? self !! self.take-value();
    }

    ##========================================================
    ## Normalize per tag type
    ##========================================================
    #| Normalize the inverse indexes per tag type.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<$object> Should the result be an object or not?
    method normalize-per-tag-type($normSpec = 'euclidean', Bool :$object = True) {

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

        return $object ?? self !! True;
    }

    ##========================================================
    ## Normalize per tag type per item
    ##========================================================
    #| Normalize the inverse indexes per tag type per item.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<:$object> Should the result be an object or not?
    method normalize-per-tag-type-per-item($normSpec = 'euclidean', Bool :$object = True) {

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

        # This has to be refactored!
        # Same type coercion is done in make-tag-inverse-indexes.
        %!tagInverseIndexes = %!tagInverseIndexes.map({ $_.key => $_.value.Mix });

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        return $object ?? self !! True;
    }
    #| Interpretation: each row of the SMR matrix is partitioned in tag type sub-vectors
    #| and those sub-vectors are normalized.

    ##========================================================
    ## Normalize per tag
    ##========================================================
    #| Normalize the inverse indexes per tag.
    #| * C<$normSpec> Norm specification. See <UtilityFunctions::norm>.
    #| * C<$object> Should the result be an object or not?
    method normalize-per-tag($normSpec = 'euclidean', Bool :$object = True) {

        ## Normalize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    my $norm = self.norm($v.values, $normSpec);
                    $k => $v <</>> ($norm > 0 ?? $norm !! 1)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        return $object ?? self !! True;
    }

    ##========================================================
    ## Unitize
    ##========================================================
    #| Unitize the inverse indexes.
    #| * C<$object> Should the result be an object or not?
    multi method unitize(Bool :$object = True) {

        ## Unitize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    $k => Mix($v.keys)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        return $object ?? self !! True;
    }

    ##========================================================
    ## Global weights
    ##========================================================
    #| Compute global weights for the keys of the inverse indexes.
    #| * C<$spec> Global weight function spec; one of C<<IDF GFIDF Binary None Normal ColumnStochastic Sum>>.
    #| * C<$object> Should the result be an object or not?
    method global-weights($spec = 'IDF', Bool :$object = True) {

        my %colSums = Hash(%!tagInverseIndexes.keys Z=> %!tagInverseIndexes.values>>.total);
        %colSums = %colSums.deepmap({ $_ > 0 ?? $_ !! $_ });

        my $nrows = %!tagInverseIndexes.values>>.keys.flat.unique.elems;

        ## Main switch
        given $spec {
            when $_ eq 'IDF' or $_.isa(Whatever) {
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
                %!globalWeights = Hash(%!tagInverseIndexes.keys X=> 1)
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

        # Result
        self.set-value(%!globalWeights);

        return $object ?? self !! %!globalWeights;
    }

    ##========================================================
    ## Classify
    ##========================================================
    #| Classify by profile vector.
    #| C<$tagType> -- Tag type to classify to.
    #| C<$profile> -- A tag, a list of tags, a dictionary of scored tags.
    #| C<:$n-top-nearest-neighbors> -- Number of top nearest neighbors to use.
    #| C<:$voting> -- Should simple voting be used or a weighted sum?
    #| C<:$max-number-of-labels> -- The maximum number of labels to be returned; if None all found labels are returned.
    #| C<:$drop-zero-scored-labels> -- Should the labels with zero scores be dropped or not?
    #| C<:$normalize> -- Should the scores be normalized?
    #| C<:$ignore-unknown> -- Should the unknown tags be ignored or not?
    #| C<$object> -- Should the result be an object or not?
    multi method classify-by-profile(Str $tagType, @profile, *%args) {
        return self.classify-by-profile($tagType, %(@profile X=> 1.0).Mix, |%args);
    }

    multi method classify-by-profile(Str $tagType,
                                     Mix:D $profile,
                                     UInt :$n-top-nearest-neighbors = 100,
                                     Bool :$voting = False,
                                     Bool :$drop-zero-scored-labels = True,
                                     :$max-number-of-labels = Whatever,
                                     Bool :$normalize = True,
                                     Bool :$ignore-unknown = False,
                                     Bool :$object = True) {

        # Verify tag_type
        if $tagType ∉ %!tagTypeToTags.keys {
            die "The value of the first argument $tagType is not a known tag type.";
        }

        # Compute the recommendations
        my %recs = self.recommend-by-profile($profile, $n-top-nearest-neighbors, warn => !$ignore-unknown):!object;

        # "Nothing" result
        if %recs.elems == 0 {
            self.set-value({});
            return $object ?? self !! {};
        }

        # Get the tag type sub-matrix, i.e. the corresponding inverse indexes.
        # Not used because it seems faster to just use %!itemInverseIndexes .
        #%!tagTypeToTags{$tagType}.cache;
        #my %matTagType = [|%!tagTypeToTags{$tagType}] Z=> %!tagInverseIndexes{ |%!tagTypeToTags{$tagType} };

        #my %tMatTagType = self.transpose(%matTagType);

        # Respect voting
        if $voting {
            %recs = self.unitize(%recs)
        }

        ## Get scores
        if !%!itemInverseIndexes { self.transpose-tag-inverse-indexes }
        my %clRecs = [(+)] %!itemInverseIndexes{%recs.keys} Z<<*>> %recs.values;
        %clRecs = %clRecs.grep({ $_.key ∈ %!tagTypeToTags{$tagType} }).cache;

        # Drop zero scored labels
        if $drop-zero-scored-labels {
            %clRecs = %clRecs.grep({ $_.value > 0 }).cache;
        }

        # Normalize
        if $normalize {
            %clRecs = self.normalize(%clRecs, 'max-norm');
        }

        # Reverse sort
        my @clRecs = %clRecs.pairs.sort(-*.value);

        # Pick max-top labels
        if $max-number-of-labels ~~ Numeric and $max-number-of-labels > 0 and $max-number-of-labels < @clRecs.elems {
            @clRecs = @clRecs.head($max-number-of-labels).Array;
        }

        # Result
        self.set-value(@clRecs);

        return $object ?? self !! @clRecs;
    }

    ##========================================================
    ## Prove by metadata
    ##========================================================
    multi method prove-by-metadata(@profile, @items) {
        return self.prove-by-metadata(%( @profile X=> 1.0), @items);
    }

    multi method prove-by-metadata(%profile, @items) {
        note "Proving by metadata is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Prove by history
    ##========================================================
    multi method prove-by-history(@history, @items) {
        return self.prove-by-history(%( @history X=> 1.0), @items);
    }

    multi method prove-by-history(%history, @items) {
        note "Proving by history is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Remove tag type(s)
    ##========================================================
    #| Remove tag types.
    #| * C<@tagTypes> A list of tag types to be removed
    method remove-tag-types(@tagTypes) {

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

        return self;
    }

    ##========================================================
    ## Filter matrix
    ##========================================================
    multi method filter-matrix(%profile) {
        return self.filter-matrix(%profile.values);
    }

    multi method filter-matrix(@profile) {
        note "Filter matrix is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- Join
    ##========================================================
    method join($smr2, Str $type = 'same') {
        my @expectedJoinTypes = <same outer union inner left>;
        note "Recommender joining is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- Annex matrix
    ##========================================================
    method annex-sub-matrix(%matrixInverseIndexes, Str $newTagType) {
        note "Annexing of a sub-matrix is not implemented yet.";
        return self;
    }

    ##========================================================
    ## Recommenders algebra -- To tag type recommender
    ##========================================================
    method make-tag-type-recommender(Str $tagTypeTo, @tagTypes) {
        note "Tag type recommender making is not implemented yet.";
        return self;
    }
}
