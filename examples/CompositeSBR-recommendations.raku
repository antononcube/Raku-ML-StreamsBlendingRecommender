#!/usr/bin/env perl6
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::CoreSBR;
use ML::StreamsBlendingRecommender::CompositeSBR;

##===========================================================
my Str $fileName =  $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';

my $sbrObj = ML::StreamsBlendingRecommender::CoreSBR.new;
$sbrObj.ingestSMRMatrixCSVFile($fileName, :make);

#my $sbrObj2 = ML::StreamsBlendingRecommender::CoreSBR.new;
#$sbrObj2.ingestSMRMatrixCSVFile($fileName, :make);
my $sbrObj2 = $sbrObj.clone();
say '$sbrObj2.takeTagInverseIndexes().elems = ', $sbrObj2.takeTagInverseIndexes().elems;

say '$sbrObj2.takeTagTypeToTags(): ', $sbrObj2.takeTagTypeToTags();

say "-" x 30;

say '$sbrObj.takeSMRMatrix.elems = ', $sbrObj.takeSMRMatrix.elems;

say '$sbrObj.takeTagInverseIndexes().elems = ', $sbrObj.takeTagInverseIndexes().elems;

say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

$sbrObj.removeTagTypes(['passengerClass']);

say '$sbrObj.takeTagInverseIndexes().elems = ', $sbrObj.takeTagInverseIndexes().elems;

say '$sbrObj.takeTagTypeToTags(): ', $sbrObj.takeTagTypeToTags();

$sbrObj2.removeTagTypes(['passengerAge', 'passengerSex']);

say '$sbrObj2.takeTagInverseIndexes().elems = ', $sbrObj2.takeTagInverseIndexes().elems;

say '$sbrObj2.takeTagTypeToTags(): ', $sbrObj2.takeTagTypeToTags();

my $sbrCompObj = ML::StreamsBlendingRecommender::CompositeSBR.new();

$sbrCompObj.objects.push("First"=>$sbrObj);
$sbrCompObj.objects.push("Second"=>$sbrObj2);

say $sbrObj.recommendByProfile( ["male", "3rd", "survived"], 20, :!object);

say "-" x 30;

say $sbrCompObj.recommendByProfile( ["male", "3rd", "survived"], 20, Nil, :!object);

say "-" x 30;

say $sbrCompObj.recommendByProfile( ["male", "3rd", "survived"], 20, 'euclidean', :!object);

say "-" x 30;
