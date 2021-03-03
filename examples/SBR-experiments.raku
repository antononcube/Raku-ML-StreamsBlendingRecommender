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

say $sbrObj.recommendByProfile( ["male", "1st", "survived"], 12 ).takeValue;