#!/usr/bin/env perl6
use lib <. lib>;

use ML::StreamsBlendingRecommender;
use ML::StreamsBlendingRecommender::CoreSBR;

##===========================================================

#say '%?RESOURCES: ', %?RESOURCES;
#say '$*PROGRAM: ', $*PROGRAM;
say '$*CWD: ', $*CWD;

my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'RandomGoods-dfSMRMatrix.csv';
#my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrObj.ingest-smr-marrix-csv-file($fileName, :make);

#say '$sbrObj.take-smr-matrix.elems = ', $sbrObj.take-smr-matrix.elems;
#
#say '$sbrObj.take-tag-inverse-indexes().elems = ', $sbrObj.take-tag-inverse-indexes().elems;
#
#say '$sbrObj.take-tag-type-to-tags(): ', $sbrObj.take-tag-type-to-tags();

#$sbrObj.normalize-per-tag-type-per-item( 'cosine' );

say "Expected to be 0: ", $sbrObj.take-item-inverse-indexes().elems == 0;

#$sbrObj.transpose-tag-inverse-indexes();
#say '$sbrObj.take-item-inverse-indexes(): ', $sbrObj.take-item-inverse-indexes();

## RandomGoods SMR
say 'profile:', $sbrObj.profile(<lummox-1>):!object;
#
#say $sbrObj.profile(Mix('id.101' => 1, 'id.216' => 0.5), :!object, :normalize);
#
say $sbrObj.recommend(Mix('diametrical-1' => 1), 10, :!object, :!normalize);

say $sbrObj.recommend-by-profile(Mix("Good:milk" => 1, "Country:denmark" => 1), :!object, :!normalize);

## Titanic SMR
#say 'profile:', $sbrObj.profile(['id.101']).take-value;
#
#say $sbrObj.profile(Mix('id.101' => 1, 'id.216' => 0.5), :!object, :normalize);
#
#say $sbrObj.recommend(Mix('id.101' => 1, 'id.216' => 0.5), 31, :!object, :normalize).sort(*.key);
