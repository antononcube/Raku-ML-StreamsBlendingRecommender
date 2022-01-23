use Text::CSV;
use Data::Reshapers;
use Data::Reshapers::Predicates;

role ML::StreamsBlendingRecommender::UtilityFunctions {

    ##========================================================
    ## Faster reverse-sort function using NQP
    ##========================================================
    #method nqp-reverse($a, $b) {
    #    use nqp;
    #    nqp::isge_n($a.value, $b.value) ?? False !! True
    #}

    ##========================================================
    ## Norm
    ##========================================================
    sub safeInversion(Numeric $n) returns Numeric {
        $n == 0 ?? 1 !! 1 / $n
    }

    ##========================================================
    ## Norm
    ##========================================================

    multi method norm(Associative $mix, $spec = 'euclidean') returns Numeric {
        self.norm($mix.values, $spec)
    }

    multi method norm(@vec, $spec = 'euclidean') returns Numeric {
        given $spec {
            when $_ (elem) <max-norm inf-norm inf infinity> { @vec.map({ abs($_) }).max }
            when $_.Str eq '1' or $_ (elem) <one-norm one sum> { @vec.map({ abs($_) }).sum }
            when $_.isa(Whatever) or $_
                    .Str eq '2' or $_ (elem) <euclidean cosine two-norm two> { sqrt(sum(@vec <<*>> @vec)) }
            default { die "Unknown norm specification '$spec'."; }
        }
    }

    ##========================================================
    ## Normalize
    ##========================================================
    multi method normalize(Associative $mix, $spec = "euclidean") {
        $spec eq 'none' ?? $mix !! $mix <<*>> safeInversion(self.norm($mix, $spec))
    }

    multi method normalize(@vec, $spec = 'euclidean') {
        $spec eq 'none' ?? @vec !! @vec <<*>> safeInversion(self.norm(@vec, $spec))
    }

    ##========================================================
    ## IngestCSVFile
    ##========================================================
    #| Ingest CSV file.
    #| * C<$fileName> CSV file name.
    #| * C<$mapper> Maps internal to actual column names.
    #| * C<$naive-parsing> Should naive parsing be used or not?
    #| * C<$sep> Separator of CSV fields.
    method ingestCSVFile(Str $fileName,
                         %mapper = %(Item => 'Item',
                                     TagType => 'TagType',
                                     Value => 'Value',
                                     Weight => 'Weight'),
                         Bool :$naive-parsing = False,
                         Str :$sep = ','
            --> Array) {

        my @res;

        if $naive-parsing {
            # It 7-10 faster to use this ad-hoc code than the standard Text::CSV workflow.
            # But some tags might have commas (i.e. the separator) in them.
            # Also, string values should not have surrounding quotes.
            my $fileHandle = $fileName.IO;
            my Str @records = $fileHandle.lines;
            my @colNames = @records[0].split($sep);
            @res = @records[1 .. *- 1].map({ %( @colNames Z=> $_.split($sep)) });
        } else {
            my $csv = Text::CSV.new;
            @res = $csv.csv(in => $fileName, headers => 'auto');
        }

        my @expectedColumnNames = %mapper.values;

        if (@res[0].keys (&) @expectedColumnNames).elems < @expectedColumnNames.elems {
            warn "The ingested CSV file does not have the expected column names: { @expectedColumnNames.join(', ') }.";
            return Nil;
        }

        my %mapperInv = %mapper.invert;
        @res = @res>>.map({ %mapperInv{.key}:exists ?? (%mapperInv{.key} => .value) !! $_ })>>.Hash;

        return @res;
    }

    ##========================================================
    ## Join across
    ##========================================================
    method joinAcross( @dataset, :$by is copy = Whatever, Bool :$object = True ) {

        if not is-array-of-hashes(@dataset) {
            warn 'The first argument is expected to be an array of hashes.';
            return $object ?? self !! Nil;
        }

        if $by.isa(Whatever) {

            given @dataset[0].keys.Array {
                when 'id' (elem) $_>>.lc { $by = $_.first({ $_.lc eq 'id' }) }
                when 'item' (elem) $_>>.lc { $by = $_.first({ $_.lc eq 'item' }) }
                default { $by = @dataset[0].keys[0] }
            }
            warn  "Heuristically picking the joining column to be '$by'.";
        }

        my $recs = self.takeValue.Array;
        if is-array-of-pairs($recs) {
            self.setValue( join-across($recs.map({ %( $by => $_.key, Score => $_.value ) }), @dataset, $by).sort(-*<Score>) );
        } else {
            warn "Object's value is not an array of pairs.";
            return $object ?? self !! Nil;
        }

        if $object { self } else { self.takeValue() }
    }
}
