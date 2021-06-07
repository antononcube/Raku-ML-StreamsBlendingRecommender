#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::LSAEndowedSBR;

##===========================================================
#my $datasetID = 'RandomGoods';
my $datasetID = 'WLExampleData';
my Str $fileName = $*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfLSATopicWordMatrix.csv';

my $sbrLSAObj = ML::StreamsBlendingRecommender::LSATopicSBR.new;

$sbrLSAObj.ingestLSAMatrixCSVFile($fileName);
$sbrLSAObj.ingestGlobalWeightsCSVFile($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfLSAWordGlobalWeights.csv');
$sbrLSAObj.ingestStemRulesCSVFile($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfStemRules.csv');

say '$sbrLSAObj.takeSMRMatrix.elems = ', $sbrLSAObj.takeSMRMatrix.elems;

$sbrLSAObj.makeTagInverseIndexes();

say '$sbrLSAObj.takeTagTypeToTags(): ', $sbrLSAObj.takeTagTypeToTags();

#$sbrLSAObj.normalizePerTagType( 'cosine' );

say '$sbrLSAObj.takeInverseIndexes.elems = ', $sbrLSAObj.takeTagInverseIndexes.elems;

say '$sbrLSAObj.takeInverseIndexes.keys = ', $sbrLSAObj.takeTagInverseIndexes.keys;

say "-" x 60;

my $recs = $sbrLSAObj.recommendByText("ozone in los angelis", 10):!object;

say $recs;

##===========================================================
say "=" x 60;

my $sbrCoreObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrCoreObj.ingestSMRMatrixCSVFile($*CWD.Str ~ '/resources/' ~ $datasetID ~ '-dfSMRMatrix.csv');

say '$sbrCoreObj.takeSMRMatrix.elems = ', $sbrCoreObj.takeSMRMatrix.elems;

$sbrCoreObj.makeTagInverseIndexes();

say '$sbrCoreObj.takeTagTypeToTags(): ', $sbrCoreObj.takeTagTypeToTags();

#$sbrLSAObj.normalizePerTagType( 'cosine' );

say '$sbrCoreObj.takeInverseIndexes.elems = ', $sbrCoreObj.takeTagInverseIndexes.elems;

say '$sbrCoreObj.takeInverseIndexes.keys = ', $sbrCoreObj.takeTagInverseIndexes.keys;


say "-" x 60;

#my $recs2 = $sbrCoreObj.recommendByProfile(["Good:milk", "Country:denmark", "UserID:frehvojwf"], 10):!object;
my $recs2 = $sbrCoreObj.recommendByProfile(["ApplicationArea:Chemistry", "DataType:MultivariateSample"], 10):!object:normalize;

say $recs2;

##===========================================================
say "=" x 60;

my $sbrWithLSAObj = ML::StreamsBlendingRecommender::LSAEndowedSBR.new;

$sbrWithLSAObj.Core = $sbrCoreObj;
$sbrWithLSAObj.LSA = $sbrLSAObj;

#my $recs3 =
#        $sbrWithLSAObj.recommendByProfile(
#                ["Good:milk", "Country:denmark", "UserID:frehvojwf"],
#                "perambulate formic acquired",
#                10):!object;

my $tagsQuery =  ["ApplicationArea:Aviation", "DataType:TimeSeries"];
my $query = 'airline time series';

say "-" x 30;
say "Represent by terms:  ", $sbrLSAObj.representByTerms($query):!object;

say "-" x 30;
say "Represent by topics: ", $sbrLSAObj.representByTopics($query,):!object;

say "-" x 30;
my $recs3 = $sbrWithLSAObj.recommendByProfile( $tagsQuery, $query, 10, profileNormalizer => 'euclidean' ):!object;

say $recs3;