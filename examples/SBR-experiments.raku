#!/usr/bin/env perl6
use lib <. lib>;

use ML::StreamsBlendingRecommender::CoreSBR;

##===========================================================
my $fileName = "/Users/antonov/R/StreamsBlendingRecommender/output/dfSMRMatrixTitanic.csv";

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;

$sbrObj.ingest-smr-marrix-csv-file($fileName);

say '$sbrObj.take-smr-matrix.elems = ', $sbrObj.take-smr-matrix.elems;

$sbrObj.make-tag-inverse-indexes();

say '$sbrObj.take-tag-type-to-tags(): ', $sbrObj.take-tag-type-to-tags();

#$sbrObj.normalize-per-tag-type( 'cosine' );

$sbrObj.normalize-per-tag-type-per-item( 'cosine' );

#$sbrObj.normalize-per-tag( 'cosine' );

#$sbrObj.unitize();

say '$sbrObj.takeInverseIndexes.elems = ', $sbrObj.take-tag-inverse-indexes.elems;

say '$sbrObj.takeInverseIndexes.keys = ', $sbrObj.take-tag-inverse-indexes.keys;

say "-" x 30;

say 'IDF:', $sbrObj.global-weights('IDF').take-global-weights;
say 'Normal:', $sbrObj.global-weights('Normal').take-global-weights;
say 'Binary:', $sbrObj.global-weights('Binary').take-global-weights;
say 'Sum:', $sbrObj.global-weights('Sum').take-global-weights;
