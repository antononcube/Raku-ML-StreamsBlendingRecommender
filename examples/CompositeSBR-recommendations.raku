#!/usr/bin/env perl6
use lib <. lib>;

use ML::StreamsBlendingRecommender::CoreSBR;
use ML::StreamsBlendingRecommender::CompositeSBR;

##===========================================================
my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;
$sbrObj.ingest-smr-marrix-csv-file($fileName, :make);

#my $sbrObj2 = ML::StreamsBlendingRecommender::CoreSBR.new;
#$sbrObj2.ingest-smr-marrix-csv-file($fileName, :make);
my $sbrObj2 = $sbrObj.clone();
say '$sbrObj2.take-tag-inverse-indexes().elems = ', $sbrObj2.take-tag-inverse-indexes().elems;

say '$sbrObj2.take-tag-type-to-tags(): ', $sbrObj2.take-tag-type-to-tags();

say "-" x 30;

say '$sbrObj.take-smr-matrix.elems = ', $sbrObj.take-smr-matrix.elems;

say '$sbrObj.take-tag-inverse-indexes().elems = ', $sbrObj.take-tag-inverse-indexes().elems;

say '$sbrObj.take-tag-type-to-tags(): ', $sbrObj.take-tag-type-to-tags();

$sbrObj.remove-tag-types(['passengerClass']);

say '$sbrObj.take-tag-inverse-indexes().elems = ', $sbrObj.take-tag-inverse-indexes().elems;

say '$sbrObj.take-tag-type-to-tags(): ', $sbrObj.take-tag-type-to-tags();

$sbrObj2.remove-tag-types(['passengerAge', 'passengerSex']);

say '$sbrObj2.take-tag-inverse-indexes().elems = ', $sbrObj2.take-tag-inverse-indexes().elems;

say '$sbrObj2.take-tag-type-to-tags(): ', $sbrObj2.take-tag-type-to-tags();

my $sbrCompObj = ML::StreamsBlendingRecommender::CompositeSBR.new();

$sbrCompObj.objects.push("First"=>$sbrObj);
$sbrCompObj.objects.push("Second"=>$sbrObj2);
$sbrCompObj.weights.push( { "First" => 1, "Second" => 0.6} );

say $sbrObj.recommend-by-profile( ["male", "3rd", "survived"], 20, :!object);

say "-" x 30;

say $sbrCompObj.recommend-by-profile( ["male", "3rd", "survived"], 20, Nil, :!object);

say "-" x 30;

say $sbrCompObj.recommend-by-profile( ["male", "3rd", "survived"], 20, 'euclidean', :!object);

say "-" x 30;
