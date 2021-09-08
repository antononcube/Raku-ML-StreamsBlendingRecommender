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
            when $_.isa(Whatever) or $_.Str eq '2' or $_ (elem) <euclidean cosine two-norm two> { sqrt(sum(@vec <<*>> @vec)) }
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
}
