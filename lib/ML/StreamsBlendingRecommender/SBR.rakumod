use v6;

use Text::CSV;

## Monadic-like definition.
class SBR {

    ## Data members
    has @!SMRMatrix;
    has %!inverseIndexes = %();
    has %!value;

    ## Setters
    method setSMRMatrix( @arg ) { @!SMRMatrix = @arg; self }

    ## Takers
    method takeSMRMatrix() { @!SMRMatrix }
    method takeInverseIndexes() { %!inverseIndexes }
    method takeValue() { %!value }

    ## Ingest a CSV file
    method ingestCSVFile(Str $fileName) {

        my $csv = Text::CSV.new;
        @!SMRMatrix = $csv.csv(in => $fileName, headers => "auto");

        self
    }

    ## Make inverse indexes
    method makeInverseIndexes() {

        ## Split into a hash by tag type.
        my %inverseIndexGroups = @!SMRMatrix.classify({ $_<TagType> });

        ## For each tag type split into hash by Value.
        my %inverseIndexesPerTagType = %inverseIndexGroups.pairs.map({ $_.key => $_.value.classify({ $_<Value> }) });

        ## Re-make each array of hashes into a hash.
        %inverseIndexesPerTagType =
                %inverseIndexesPerTagType.pairs.map({ $_.key => $_.value.pairs.map({ $_.key => Mix($_.value.map({ $_<Item> => $_<Weight> })) }) });

        ## Make it a hash of hashes of mixes.
        %inverseIndexesPerTagType =
                Hash(%inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map({ Hash($_) }));

        ## Flatten the inverse index groups.
        %!inverseIndexes = %();
        for %inverseIndexesPerTagType.values -> %h { %!inverseIndexes.append(%h) };

        self
    }

    ## Recommend by profile array
    multi method recommendByProfile( @prof, Int:D $nrecs = 12) {
        self.recommendByProfile(Mix(@prof), $nrecs)
    }

    ## Recommend by profile mix
    multi method recommendByProfile(Mix:D $prof, Int:D $nrecs = 12) {

        ## This initial version might be potentially slow.
        # my $knownTags = $prof.keys (&) %!inverseIndexes.keys;
        #
        # if $knownTags.elems == 0 {
        #            warn 'All profile tags are unknown in the recommender.';
        #            %!value = %();
        #            return self
        # }
        #
        # my $profQuery = Mix( $prof{ $knownTags.keys }:p );

        my $profQuery = Mix( $prof );

        my %profMixes = Bag.new;
        my $found = False;

        for $profQuery.keys -> $k {
            if %!inverseIndexes{$k}:exists {
                $found = True;
                %profMixes = %!inverseIndexes{$k} <<*>> $profQuery{$k} (+) %profMixes
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

}
