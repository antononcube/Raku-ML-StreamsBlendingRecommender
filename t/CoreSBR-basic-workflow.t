use v6;
use lib './lib';
use lib '.';
use ML::StreamsBlendingRecommender::CoreSBR;
use Test;

plan 3;

#my Str $fileNameFreq = %?RESOURCES<dfSMRMatrixTitanic-Freq.csv>.Str;
#my Str $fileNameIDF = %?RESOURCES<dfSMRMatrixTitanic-IDF.csv>.Str;

##-----------------------------------------------------------
## Creation and ingestion
##-----------------------------------------------------------

#my Str $fileNameFreq = $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-Freq.csv';
my Str $fileNameIDF = $*CWD.Str ~ '/resources/' ~ 'dfSMRMatrixTitanic-IDF.csv';

my $sbrFreq = ML::StreamsBlendingRecommender::CoreSBR.new;
my $sbrIDF = ML::StreamsBlendingRecommender::CoreSBR.new;

#ok $fileNameFreq.chars > 0, '$fileNameFreq';

ok $fileNameIDF.chars > 0, '$fileNameIDF';

#ok $sbrFreq.ingestSMRMatrixCSVFile($fileNameFreq).takeSMRMatrix.elems > 800,
#        '$sbrFreq.ingestSMRMatrixCSVFile($fileNameFreq).takeSMRMatrix.elems';

ok $sbrIDF.ingestSMRMatrixCSVFile($fileNameIDF, :make).takeSMRMatrix.elems > 800,
        '$sbrIDF.ingestSMRMatrixCSVFile($fileNameIDF, :make).takeSMRMatrix.elems';


##-----------------------------------------------------------
## Recommendations by profile array
##-----------------------------------------------------------
my %recsIDF = $sbrIDF.recommendByProfile(['1st', 'survived', 'male'], 120, :!object);
my $resKeysIDF = %recsIDF.grep( *.value >= 3 ).sort( *.key ).hash.keys.sort;

#my $expected = $sbrIDF.takeSMRMatrix().filter( {} );

ok %recsIDF.elems == 120,
        'recsIDF.elems';

done-testing;
