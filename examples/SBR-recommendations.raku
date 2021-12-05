#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender;
use ML::StreamsBlendingRecommender::CoreSBR;

##===========================================================

#say '%?RESOURCES: ', %?RESOURCES;
#say '$*PROGRAM: ', $*PROGRAM;
say '$*CWD: ', $*CWD;

my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'RandomGoods-dfSMRMatrix.csv';
#my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrObj.ingestSMRMatrixCSVFile($fileName, :make);

#say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;
#
#say '$sbrObj.takeTagInverseIndexes().elems = ', $sbrObj.takeTagInverseIndexes().elems;
#
#say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

#$sbrObj.normalizePerTagTypePerItem( 'cosine' );

say "Expected to be 0: ", $sbrObj.takeItemInverseIndexes().elems == 0;

#$sbrObj.transposeTagInverseIndexes();
#say '$sbrObj.takeItemInverseIndexes(): ', $sbrObj.takeItemInverseIndexes();

## RandomGoods SMR
say 'profile:', $sbrObj.profile(<lummox-1>):!object;
#
#say $sbrObj.profile(Mix('id.101' => 1, 'id.216' => 0.5), :!object, :normalize);
#
say $sbrObj.recommend(Mix('diametrical-1' => 1), 10, :!object, :!normalize);

say $sbrObj.recommendByProfile(Mix("Good:milk" => 1, "Country:denmark" => 1), :!object, :!normalize);

## Titanic SMR
#say 'profile:', $sbrObj.profile(['id.101']).takeValue;
#
#say $sbrObj.profile(Mix('id.101' => 1, 'id.216' => 0.5), :!object, :normalize);
#
#say $sbrObj.recommend(Mix('id.101' => 1, 'id.216' => 0.5), 31, :!object, :normalize).sort(*.key);
