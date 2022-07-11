#!/usr/bin/env perl6

use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::CoreSBR;

use Data::Reshapers;
use ML::TriesWithFrequencies;

##===========================================================
my @dsTitanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');

my ML::StreamsBlendingRecommender::CoreSBR $sbrObj .= new;

$sbrObj.makeTagInverseIndexesFromWideForm(@dsTitanic, tagTypes => @dsTitanic[0].keys.grep({ $_ ne 'id' }).Array, itemColumnName => <id>).transposeTagInverseIndexes;

my $recs;
my $obj;

#========================================================================================================================
say '=' x 120;
say 'Filter by profile, union';
say '-' x 120;

$recs = $sbrObj.filterByProfile(["passengerClass:1st", "passengerSex:male"], type => 'union'):!object;

say $recs.pick(6).List;
say $recs.elems;

say '-' x 120;
say 'Dataset query check:';

$obj = @dsTitanic ;
$obj = $obj.grep({ $_{"passengerSex"} eq "male" or $_{"passengerClass"} eq "1st" }).Array ;
say "counts : {$obj.elems}";

#========================================================================================================================
say '=' x 120;
say 'Filter by profile, intersection';
say '-' x 120;

$recs = $sbrObj.filterByProfile(["passengerClass:1st", "passengerSex:male"], type => 'intersection'):!object;

say $recs.pick(6).List;
say $recs.elems;

say '-' x 120;
say 'Dataset query check:';

$obj = @dsTitanic ;
$obj = $obj.grep({ $_{"passengerSex"} eq "male" and $_{"passengerClass"} eq "1st" }).Array ;
say "counts : {$obj.elems}";

#========================================================================================================================
say '=' x 120;
say 'Retrieve by query elements';
say '-' x 120;

$recs = $sbrObj.retrieveByQueryElements(
        should => 'passengerSurvival:survived',
        must => 'passengerSex:male',
        mustNot => 'passengerClass:3rd',
        mustType => 'intersection'):!object;

say $recs.head(12);
say 'all        : ', $recs.elems;
say 'high score : ', $recs.grep({ $_.value > 1 }).elems;

say '-' x 120;
say 'Dataset query check:';

$obj = @dsTitanic ;
$obj = $obj.grep({ $_{"passengerSex"} eq "male" and $_{"passengerClass"} ne "3rd" }).Array ;
say "counts : {$obj.elems}";

$obj = @dsTitanic ;
$obj = $obj.grep({ $_{"passengerSex"} eq "male" and $_{"passengerSurvival"} eq "survived" and $_{"passengerClass"} ne "3rd" }).Array ;
say "counts : {$obj.elems}";