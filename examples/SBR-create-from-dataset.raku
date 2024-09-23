#!/usr/bin/env perl6

use lib <. lib>;
use ML::StreamsBlendingRecommender::CoreSBR;

use Data::Reshapers;

##===========================================================
my Hash @titanic = Data::Reshapers::get-titanic-dataset(headers => 'auto');

.say for @titanic.roll(4);

say @titanic[0].keys.grep({ $_ ne 'id' });

my ML::StreamsBlendingRecommender::CoreSBR $sbrObj .= new;

$sbrObj.make-tag-inverse-indexes-from-wide-form( @titanic, tagTypes => @titanic[0].keys.grep({ $_ ne 'id' }).Array, itemColumnName => <id> );

say 'global-weights : ', $sbrObj.global-weights('IDF'):!object;

say '$sbrObj.take-tag-inverse-indexes().keys :', $sbrObj.take-tag-inverse-indexes().keys;

say '$sbrObj.take-tag-inverse-indexes() :', $sbrObj.take-tag-inverse-indexes();

my $recs = $sbrObj.recommend-by-profile( ["passengerClass:1st", "passengerSex:male"], 1000):!object;

say $recs;

say @titanic.grep({ $_<id> (elem) %($recs).keys });

say "-" x 60;