#!/usr/bin/env perl6
use lib <. lib>;

use ML::StreamsBlendingRecommender::LSAEndowedSBR;

##===========================================================
#my $datasetID = 'RandomGoods';
my $datasetID = 'WLExampleData';
my Str $fileName = $*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfLSATopicWordMatrix.csv';

my $sbrLSAObj = ML::StreamsBlendingRecommender::LSATopicSBR.new;

$sbrLSAObj.ingest-lsa-matrix-csv-file($fileName);
$sbrLSAObj.ingest-global-weights-csv-file($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfLSAWordGlobalWeights.csv');
$sbrLSAObj.ingest-stem-rules-csv-file($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfStemRules.csv');

say '$sbrLSAObj.take-smr-matrix.elems = ', $sbrLSAObj.take-smr-matrix.elems;

$sbrLSAObj.make-tag-inverse-indexes();

say '$sbrLSAObj.take-tag-type-to-tags(): ', $sbrLSAObj.take-tag-type-to-tags();

#$sbrLSAObj.normalize-per-tag-type( 'cosine' );

say '$sbrLSAObj.takeInverseIndexes.elems = ', $sbrLSAObj.take-tag-inverse-indexes.elems;

say '$sbrLSAObj.takeInverseIndexes.keys = ', $sbrLSAObj.take-tag-inverse-indexes.keys;

say "-" x 60;

my $recs = $sbrLSAObj.recommend-by-text("ozone in los angelis", 10):!object;

say $recs;

##===========================================================
say "=" x 60;

my $sbrCoreObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrCoreObj.ingest-smr-marrix-csv-file($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfSMRMatrix.csv');

say '$sbrCoreObj.take-smr-matrix.elems = ', $sbrCoreObj.take-smr-matrix.elems;

$sbrCoreObj.make-tag-inverse-indexes();

say '$sbrCoreObj.take-tag-type-to-tags(): ', $sbrCoreObj.take-tag-type-to-tags();

#$sbrLSAObj.normalize-per-tag-type( 'cosine' );

say '$sbrCoreObj.takeInverseIndexes.elems = ', $sbrCoreObj.take-tag-inverse-indexes.elems;

say '$sbrCoreObj.takeInverseIndexes.keys = ', $sbrCoreObj.take-tag-inverse-indexes.keys;


say "-" x 60;

#my $recs2 = $sbrCoreObj.recommend-by-profile(["Good:milk", "Country:denmark", "UserID:frehvojwf"], 10):!object;
my $recs2 = $sbrCoreObj.recommend-by-profile(["ApplicationArea:Chemistry", "DataType:MultivariateSample"], 10):!object:normalize;

say $recs2;

##===========================================================
say "=" x 60;

my $sbrWithLSAObj = ML::StreamsBlendingRecommender::LSAEndowedSBR.new;

$sbrWithLSAObj.Core = $sbrCoreObj;
$sbrWithLSAObj.LSA = $sbrLSAObj;

#my $recs3 =
#        $sbrWithLSAObj.recommend-by-profile(
#                ["Good:milk", "Country:denmark", "UserID:frehvojwf"],
#                "perambulate formic acquired",
#                10):!object;

my $tagsQuery =  <ApplicationArea:Aviation DataType:TimeSeries>;
my $query = 'airline time series';

say "-" x 30;
say "Represent by terms:  ", $sbrLSAObj.represent-by-terms($query):!object;

say "-" x 30;
say "Represent by topics: ", $sbrLSAObj.represent-by-topics($query,):!object;

say "-" x 30;
my $recs3 = $sbrWithLSAObj.recommend-by-profile( $tagsQuery, $query, 10, profileNormalizer => 'euclidean' ):!object;

say $recs3;