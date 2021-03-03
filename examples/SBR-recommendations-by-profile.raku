#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::SBR;

##===========================================================
my $fileName = "/Users/antonov/R/StreamsBlendingRecommender/output/dfSMRMatrixTitanic.csv";

my $sbrObj = SBR.new;

$sbrObj.ingestSMRMatrixCSVFile($fileName);

say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;

$sbrObj.makeTagInverseIndexes();

say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

#$sbrObj.normalizePerTagType( 'cosine' );

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.takeTagInverseIndexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.takeTagInverseIndexes.keys;

#say $sbrObj.recommendByProfile( <male 1st survived>, 12 ).takeValue;

say $sbrObj.recommendByProfile( ["male", "1st", "survived"], 12 ).takeValue;

say "-" x 30;

my %recs = $sbrObj.recommendByProfile( Mix( '1st' => 1.2, 'survived' => 1, 'male' => 1.1), 100 ).takeValue;

my $resKeys = %recs.grep( *.value > 3 ).sort( *.key ).hash.keys.sort;

say '|$resKeys|: ', $resKeys.elems, ' $resKeys:', $resKeys;

say SBR.norm(%recs.values, 'euclidean');
say SBR.norm(%recs.values, 'one');
say SBR.norm(%recs.values, 'inf');

# say SBR.norm(%recs.values, 'irer');
