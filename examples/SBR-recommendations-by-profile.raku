#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::CoreSBR;

##===========================================================
#my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';
#my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'RandomGoods-dfSMRMatrix.csv';
my Str $fileName = $*CWD.Str ~ '/resources/' ~ 'WLExampleData-dfSMRMatrix.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrObj.ingestSMRMatrixCSVFile($fileName);

say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;

$sbrObj.makeTagInverseIndexes();

say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

#$sbrObj.normalizePerTagType( 'cosine' );

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.takeTagInverseIndexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.takeTagInverseIndexes.keys;

#say $sbrObj.recommendByProfile( <male 1st survived>, 12 ).takeValue;

say "-" x 60;

#my $recs = $sbrObj.recommendByProfile( ["Good:milk", "Country:denmark", "UserID:frehvojwf"], 10 ):!object;
my $recs = $sbrObj.recommendByProfile( ["ApplicationArea:Aviation", "DataType:TimeSeries"], 10 ):!object;

say $recs;

say "-" x 60;

#my %recs = $sbrObj.recommendByProfile( Mix( 'Good:milk' => 1.2, 'Country:china' => 1), 40 ):!object;
my %recs = $sbrObj.recommendByProfile( Mix( 'DataType:TimeSeries' => 1.2, 'ColumnHeading:Tension' => 1), 40 ):!object;

my $resKeys = $recs.grep( *.value > 3 ).pairs.sort({ -$_.value });

say '|$resKeys|: ', $resKeys.elems, ' $resKeys:', $resKeys;

say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'euclidean');
say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'one');
say ML::StreamsBlendingRecommender::CoreSBR.norm(%recs.values, 'inf');

# say SBR.norm(%recs.values, 'irer');

