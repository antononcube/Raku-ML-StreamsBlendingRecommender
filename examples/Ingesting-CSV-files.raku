#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use Text::CSV;

##===========================================================
my $fileName = %?RESOURCES<dfSMRMatrixTitanic-Freq.csv>;

my $csv = Text::CSV.new;

say "=" x 30;
say "Ingestion:";

my $start = now;
my @dfSMRMatrix = $csv.csv(in => $fileName, headers => "auto");
say "time:", now - $start;

say "Size of CSV file records:", @dfSMRMatrix.elems;

say @dfSMRMatrix[1..5];

say @dfSMRMatrix>><Weight>;

##===========================================================
say "=" x 30;
say "Group by the tag type and show lengths:";
say "=" x 30;

my %inverseIndexGroups = @dfSMRMatrix.classify( { $_<TagType> } );

say "%inverseIndexGroups.elems = ", %inverseIndexGroups.elems;

say "%inverseIndexGroups.elems = ", Hash( %inverseIndexGroups.keys Z=> %inverseIndexGroups.values.map( {$_.elems} ) );

say "%inverseIndexGroups.keys =", %inverseIndexGroups.keys;

say "Examples: ", %inverseIndexGroups{%inverseIndexGroups.keys[0]}[1..2];

##===========================================================
say "=" x 30;
say "Make mixes per tag type group and show lengths:";
say "=" x 30;

my %inverseIndexesPerTagType = %inverseIndexGroups.pairs.map( { $_.key => $_.value.classify( { $_<Value> } ) } );

say "%inverseIndexesPerTagType.keys =", %inverseIndexesPerTagType.keys;

say "Examples: ", %inverseIndexesPerTagType{%inverseIndexesPerTagType.keys[0]};

## Re-make each array of hashes into a hash.
%inverseIndexesPerTagType =
        %inverseIndexesPerTagType
        .pairs
        .map( { $_.key => $_.value.pairs.map( { $_.key => Mix( $_.value.map( { $_<Item> => $_<Weight> } ) ) } ) } );

## Make it a hash of hashes of mixes
%inverseIndexesPerTagType = Hash( %inverseIndexesPerTagType.keys Z=> %inverseIndexesPerTagType.values.map( {Hash($_)} ) );

say "%inverseIndexesPerTagType.keys =", %inverseIndexesPerTagType.keys;

say "Examples: ", %inverseIndexesPerTagType{%inverseIndexesPerTagType.keys[0]};

say "Examples: ", %inverseIndexesPerTagType<passengerClass>;

##===========================================================
say "=" x 30;
say "All inverse indexes together:";
say "=" x 30;
my %inverseIndexes = %();
for %inverseIndexesPerTagType.values -> %h { %inverseIndexes.append(%h) };

say "%inverseIndexes.elems:", %inverseIndexes.elems;

say "%inverseIndexes.elems:", %inverseIndexes.keys;

say %inverseIndexes.pick;

##===========================================================
say "=" x 30;
say "Recommendations by profile:";
say "=" x 30;

my $prof = Mix( '1st' => 1.2, 'survived' => 1, 'male' => 1.1 );
say '$prof = ', $prof;

#my %profMixes = %inverseIndexes{ $prof.keys };

#say %inverseIndexes<1st>.map( { $_ * $prof<1st> } );

say '$prof<1st> = ', $prof<1st> ;
say '%inverseIndexes<1st> <<*>> $prof<1st> = ', %inverseIndexes<1st> <<*>> $prof<1st>;

my %profMixes = Bag.new;

for $prof.keys -> $k {
    %profMixes = %inverseIndexes{$k} <<*>> $prof{$k} (+) %profMixes
};

say %profMixes.sort(-*.value).head(60).grep(*.value > 2.5).sort(*.key);
