#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::SBR;

##===========================================================
my $fileName = "/Users/antonov/R/StreamsBlendingRecommender/output/dfSMRMatrixTitanic.csv";

my $sbrObj = SBR.new;

$sbrObj.ingestCSVFile($fileName);

say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;

$sbrObj.makeInverseIndexes();

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.takeInverseIndexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.takeInverseIndexes.keys;

#say $sbrObj.recommendByProfile( <male 1st survived>, 12 ).takeValue;

say $sbrObj.recommendByProfile( ["male0", "1st0", "survived0"], 12 ).takeValue;

say "-" x 30;

say $sbrObj.recommendByProfile( Mix( '1st' => 1.2, 'survived' => 1, 'male' => 1.1 ), 12 ).takeValue;