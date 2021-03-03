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

#$sbrObj.normalizePerTagTypePerItem( 'cosine' );

say "Expected to be 0: ", $sbrObj.takeItemInverseIndexes().elems == 0;

#$sbrObj.transposeTagInverseIndexes();
#say '$sbrObj.takeItemInverseIndexes(): ', $sbrObj.takeItemInverseIndexes();

say $sbrObj.profile(['id.101']).takeValue;

say $sbrObj.profile(Mix('id.101' => 1, 'id.216' => 0.5)).takeValue;

say $sbrObj.recommend(Mix('id.101' => 1, 'id.216' => 0.5), 31).takeValue.sort(*.key);