#!/usr/bin/env perl6

use lib <. lib>;
use ML::StreamsBlendingRecommender::CoreSBR;

use Data::Reshapers;
use ML::TriesWithFrequencies;

##===========================================================
my @dsTitanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');

my ML::StreamsBlendingRecommender::CoreSBR $sbrObj .= new;

$sbrObj.make-tag-inverse-indexes-from-wide-form(
        @dsTitanic,
        tagTypes => @dsTitanic[0].keys.grep({ $_ ne 'id' }).Array,
        itemColumnName => <id>,
        :addTagTypesToColumnNames).transpose-tag-inverse-indexes;

say '$sbrObj.take-tag-inverse-indexes.elems  : ', $sbrObj.take-tag-inverse-indexes.elems;
say '$sbrObj.take-item-inverse-indexes.elems : ', $sbrObj.take-item-inverse-indexes.elems;

say $sbrObj.take-tag-inverse-indexes.keys;

my $recs;
my $obj;

#========================================================================================================================
say '=' x 120;
say 'Recommend by profile';
say '-' x 120;

say $sbrObj.recommend-by-profile(["passengerClass:1st", "passengerSex:male"], type => 'union'):!object;

#========================================================================================================================
say '=' x 120;
say 'Filter by profile, union';
say '-' x 120;

$recs = $sbrObj.filter-by-profile(["passengerClass:1st", "passengerSex:male"], type => 'union'):!object;

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

$recs = $sbrObj.filter-by-profile(["passengerClass:1st", "passengerSex:male"], type => 'intersection'):!object;

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

$recs = $sbrObj.retrieve-by-query-elements(
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