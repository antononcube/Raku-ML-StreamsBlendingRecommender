#!/usr/bin/env perl6

use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::CoreSBR;

use Data::Reshapers;

##===========================================================
my Hash @titanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');

.say for @titanic.roll(4);

say @titanic[0].keys.grep({ $_ ne 'id' });

my ML::StreamsBlendingRecommender::CoreSBR $sbrObj .= new;

$sbrObj.makeTagInverseIndexesFromWideForm( @titanic, tagTypes => @titanic[0].keys.grep({ $_ ne 'id' }).Array, itemColumnName => <id> );

say 'globalWeights : ', $sbrObj.globalWeights('IDF'):!object;

say '$sbrObj.takeTagInverseIndexes().keys :', $sbrObj.takeTagInverseIndexes().keys;

say '$sbrObj.takeTagInverseIndexes() :', $sbrObj.takeTagInverseIndexes();

my $recs = $sbrObj.recommendByProfile( ["passengerClass:1st", "passengerSex:male"], 1000):!object;

say $recs;

say @titanic.grep({ $_<id> (elem) %($recs).keys });

say "-" x 60;