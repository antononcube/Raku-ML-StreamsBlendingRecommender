use Text::CSV;
use Data::Reshapers;
use Data::TypeSystem::Predicates;

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
    ## Unitize
    ##========================================================
    multi method unitize(%index is copy -->Hash) {

        ## Unitize.
        if %index.all ~~ Associative {
            %index =
                    do for %index.kv -> $k, $v {
                        $k => Mix($v.keys)
                    }
        } else {
            %index = Mix(%index.keys).Hash
        }

        return %index;
    }

    ##========================================================
    ## Transpose
    ##========================================================
    #| Transpose inverse indexes.
    #| * C<$inverseIndexes> Inverse indexes to transpose.
    method transpose(%inverseIndexes) {

        ## For easier interpretation the code below is written
        ## for transposing tag inverse indexes into item inverse indexes.
        ## But, of course, it applies to any hash-of-mixes.

        if !(%inverseIndexes.values.all ~~ Mix) {
            die "The first argument is expected to be a Hash of Mix-objects.";
        }

        my $items = %inverseIndexes.values>>.keys.flat.unique;

        my %transposedInverseIndexes = Hash($items Z=> Mix());

        for %inverseIndexes.kv -> $tag, $mix {
            for $mix.kv -> $item, $val {
                %transposedInverseIndexes{$item}.push($tag => $val)
            }
        }

        %transposedInverseIndexes = do for %transposedInverseIndexes.kv -> $item, $arr { $item => Mix($arr) };

        return %transposedInverseIndexes;
    }

    ##========================================================
    ## IngestCSVFile
    ##========================================================
    #| Ingest CSV file.
    #| * C<$fileName> CSV file name.
    #| * C<$mapper> Maps internal to actual column names.
    #| * C<$naive-parsing> Should naive parsing be used or not?
    #| * C<$sep> Separator of CSV fields.
    method ingest-csv-file(Str $fileName,
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
    #| Join recommendations across with a hash or dataset.
    #| C<$recs> -- Recommendations.
    #| C<@dataset> -- Dataset to join with.
    #| C<$by> -- Column name to join by.
    #| C<$object> -- Should an object be returned or not?
    multi method join-across($recs, @dataset, :$by is copy = Whatever, Bool :$object = True) {

        if not is-array-of-hashes(@dataset) {
            warn 'The first argument is expected to be an array of hashes.';
            return $object ?? self !! Nil;
        }

        if $by.isa(Whatever) {

            given @dataset[0].keys.Array {
                when 'id' (elem) $_>>.lc { $by = $_.first({ $_.lc eq 'id' }) }
                when 'item' (elem) $_>>.lc { $by = $_.first({ $_.lc eq 'item' }) }
                default { $by = @dataset[0].keys.Array[0] }
            }
            warn "Heuristically picking the joining column to be '$by'.";
        }

        if is-array-of-pairs($recs) {
            self.set-value(join-across($recs.map({ %( $by => $_.key, Score => $_.value) }), @dataset, $by)
                    .sort(-*<Score>));
        } else {
            warn "The first argument is not an array of pairs.";
            return $object ?? self !! Nil;
        }

        if $object { self } else { self.take-value() }
    }

    #| Join pipeline value across with a hash or dataset.
    #| C<@dataset> -- Dataset to join with.
    #| C<$by> -- Column name to join by.
    #| C<$object> -- Should an object be returned or not?
    multi method join-across(@dataset, :$by is copy = Whatever, Bool :$object = True) {

        my $recs = self.take-value.Array;

        if is-array-of-pairs($recs) {
            return self.join-across($recs, @dataset, :$by, :$object)
        }
        warn "Object's value is not an array of pairs.";
        return $object ?? self !! Nil;
    }

}
