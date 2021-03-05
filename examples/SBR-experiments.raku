#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use CoreSBR;

##===========================================================
my $fileName = "/Users/antonov/R/StreamsBlendingRecommender/output/dfSMRMatrixTitanic.csv";

my $sbrObj = SBR.new;

$sbrObj.ingestSMRMatrixCSVFile($fileName);

say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;

$sbrObj.makeTagInverseIndexes();

say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

#$sbrObj.normalizePerTagType( 'cosine' );

$sbrObj.normalizePerTagTypePerItem( 'cosine' );

#$sbrObj.normalizePerTag( 'cosine' );

#$sbrObj.unitize();

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.takeTagInverseIndexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.takeTagInverseIndexes.keys;

say "-" x 30;

say 'IDF:', $sbrObj.globalWeights('IDF').takeGlobalWeights;
say 'Normal:', $sbrObj.globalWeights('Normal').takeGlobalWeights;
say 'Binary:', $sbrObj.globalWeights('Binary').takeGlobalWeights;
say 'Sum:', $sbrObj.globalWeights('Sum').takeGlobalWeights;
