use v6;

use Text::CSV;

## Monadic-like definition.
class SBR {

    ##========================================================
    ## Data members
    ##========================================================
    has @!SMRMatrix;
    has %!itemInverseIndexes = %();
    has %!tagInverseIndexes = %();
    has %!tagTypeToTags = %();
    has %!globalWeights = %();
    has %!value;

    ##========================================================
    ## Setters
    ##========================================================
    method setSMRMatrix(@arg) {
        @!SMRMatrix = @arg;
        self
    }
    method setGlobalWeights(%arg) {
        %!globalWeights = %arg;
        self
    }

    ##========================================================
    ## Takers
    ##========================================================
    method takeSMRMatrix() {
        @!SMRMatrix
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
    method takeValue() {
        %!value
    }

    ##========================================================
    ## Ingest a SMR matrix CSV file
    ##========================================================
    method ingestSMRMatrixCSVFile(Str $fileName) {

        my $csv = Text::CSV.new;
        @!SMRMatrix = $csv.csv(in => $fileName, headers => "auto");

        my @expectedColumnNames = <Item TagType Value Weight>;

        if (@!SMRMatrix[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn 'The ingested CSV file does not have column names:', @expectedColumnNames, '.';
            return Nil
        }

        %!itemInverseIndexes = %();
        %!tagInverseIndexes = %();

        self
    }

    ##========================================================
    ## Make tag inverse indexes
    ##========================================================
    method makeTagInverseIndexes() {

        ## Split into a hash by tag type.
        my %inverseIndexGroups = @!SMRMatrix.classify({ $_<TagType> });

        ## For each tag type split into hash by Value.
        my %inverseIndexesPerTagType = %inverseIndexGroups.pairs.map({ $_.key => $_.value.classify({ $_<Value> }) });

        ## Re-make each array of hashes into a hash.
        %inverseIndexesPerTagType =
                %inverseIndexesPerTagType.pairs.map({ $_.key => $_.value.pairs.map({ $_.key => Mix($_.value
                        .map({ $_<Item> => $_<Weight> })) }) });

        ## Make it a hash of hashes of mixes.
        %inverseIndexesPerTagType =
                Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ Hash($_) }));

        ## Derive the tag type to tags hash map.
        %!tagTypeToTags = Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ $_.keys }));

        ## Flatten the inverse index groups.
        %!tagInverseIndexes = %();
        for %inverseIndexesPerTagType.values -> %h { %!tagInverseIndexes.append(%h) };

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        self
    }

    ##========================================================
    ## Transpose tag inverse indexes
    ##========================================================
    method transposeTagInverseIndexes() {

        ## Transpose tag inverse indexes into item inverse indexes.

        my $items = %!tagInverseIndexes.values>>.keys.flat.unique;

        %!itemInverseIndexes = Hash($items Z=> Mix());

        for %!tagInverseIndexes.kv -> $tag, $mix {
            for $mix.kv -> $item, $val {
                %!itemInverseIndexes{$item}.push($tag => $val)
            }
        }

        %!itemInverseIndexes = do for %!itemInverseIndexes.kv -> $item, $arr { $item => Mix($arr) };

        self
    }

    ##========================================================
    ## Profile
    ##========================================================
    multi method profile(@items) {
        self.profile(Mix(@items))
    }

    multi method profile(Mix:D $items) {

        my $itemsQuery = Mix($items);

        my %itemMixes = Bag.new;
        my $found = False;

        if %!itemInverseIndexes.elems == 0 { self.transposeTagInverseIndexes() }

        for $itemsQuery.keys -> $k {
            if %!itemInverseIndexes{$k}:exists {
                $found = True;
                %itemMixes = %!itemInverseIndexes{$k} <<*>> $itemsQuery{$k} (+) %itemMixes
            }
        };

        if not $found {
            warn 'All history items are unknown in the recommender.';
            %!value = %();
            return self
        }

        my @res = %itemMixes.sort(-*.value);

        %!value = @res;

        self
    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    multi method recommend(@items, Int:D $nrecs = 12) {
        self.recommend(Mix(@items), $nrecs)
    }

    multi method recommend(Mix:D $items, Int:D $nrecs = 12) {
        self.recommendByProfile( Mix(self.profile($items).takeValue), $nrecs)
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    multi method recommendByProfile(@prof, Int:D $nrecs = 12) {
        self.recommendByProfile(Mix(@prof), $nrecs)
    }

    multi method recommendByProfile(Mix:D $prof, Int:D $nrecs = 12) {

        my $profQuery = Mix($prof);

        my %profMixes = Bag.new;
        my $found = False;

        for $profQuery.keys -> $k {
            if %!tagInverseIndexes{$k}:exists {
                $found = True;
                %profMixes = %!tagInverseIndexes{$k} <<*>> $profQuery{$k} (+) %profMixes
            }
        };

        if not $found {
            warn 'All profile tags are unknown in the recommender.';
            %!value = %();
            return self
        }

        my @res = %profMixes.sort(-*.value);

        %!value = do if $nrecs < @res.elems { @res.head($nrecs) } else { @res };

        self
    }

    ##========================================================
    ## Norm
    ##========================================================
    multi method norm(Associative $mix, Str $spec = "euclidean") {
        self.norm($mix.values, $spec)
    }

    multi method norm(@vec, Str $spec = 'euclidean') {
        given $spec {
            when $_ (elem) <max-norm inf-norm inf infinity> { @vec.map({ abs($_) }).max }
            when $_ (elem) <one-norm one sum> { @vec.map({ abs($_) }).sum }
            when $_ (elem) <euclidean cosine two-norm two> { sqrt(sum(@vec <<*>> @vec)) }
            default { die "Unknwon norm specification '$spec'."; }
        }
    }

    ##========================================================
    ## Normalize per tag type
    ##========================================================
    method normalizePerTagType($normSpec) {

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

        self
    }

    ##========================================================
    ## Normalize per tag type per item
    ##========================================================
    method normalizePerTagTypePerItem($normSpec) {

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

        self
    }

    ##========================================================
    ## Normalize per tag
    ##========================================================
    method normalizePerTag($normSpec) {

        ## Normalize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    my $norm = self.norm($v.values, $normSpec);
                    $k => $v <</>> ($norm > 0 ?? $norm !! 1)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        self
    }

    ##========================================================
    ## Unitize
    ##========================================================
    method unitize() {

        ## Unitize.
        %!tagInverseIndexes =
                do for %!tagInverseIndexes.kv -> $k, $v {
                    $k => Mix($v.keys)
                }

        ## We make sure item inverse indexes are empty.
        %!itemInverseIndexes = %();

        self
    }

    ##========================================================
    ## Global weights
    ##========================================================
    method globalWeights($spec) {

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

        self
    }

}
