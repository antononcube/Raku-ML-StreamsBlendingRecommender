#!/usr/bin/env perl6
use lib <. lib>;

use ML::StreamsBlendingRecommender::CoreSBR;

##===========================================================
#my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';
#my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'RandomGoods-dfSMRMatrix.csv';
my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'WLExampleData-dfSMRMatrix.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrObj.ingest-smr-marrix-csv-file($fileName);

say '$sbrObj.take-smr-matrix.elems = ', $sbrObj.take-smr-matrix.elems;

$sbrObj.make-tag-inverse-indexes();

say '$sbrObj.take-tag-type-to-tags(): ', $sbrObj.take-tag-type-to-tags();

#$sbrObj.normalize-per-tag-type( 'cosine' );

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.take-tag-inverse-indexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.take-tag-inverse-indexes.keys;

#say $sbrObj.recommend-by-profile( <male 1st survived>, 12 ).take-value;

say "-" x 60;

#my $recs = $sbrObj.recommend-by-profile( ["Good:milk", "Country:denmark", "UserID:frehvojwf"], 10 ):!object;
my $recs = $sbrObj.recommend-by-profile( ["ApplicationArea:Aviation", "DataType:TimeSeries"], 10 ):!object;

say $recs;

say "-" x 60;

#my %recs = $sbrObj.recommend-by-profile( Mix( 'Good:milk' => 1.2, 'Country:china' => 1), 40 ):!object;
my %recs = $sbrObj.recommend-by-profile( Mix( 'DataType:TimeSeries' => 1.2, 'ColumnHeading:Tension' => 1), 40 ):!object;

my $resKeys = $recs.grep( *.value > 3 ).pairs.sort({ -$_.value });

say '|$resKeys|: ', $resKeys.elems, ' $resKeys:', $resKeys;

say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'euclidean');
say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'one');
say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'inf');

# say SBR.norm(%recs.values, 'irer');

