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
    multi method norm(Associative $mix, Str $spec = "euclidean") returns Numeric {
        self.norm($mix.values, $spec)
    }

    multi method norm(@vec, Str $spec = 'euclidean') returns Numeric {
        given $spec {
            when $_ (elem) <max-norm inf-norm inf infinity> { @vec.map({ abs($_) }).max }
            when $_ (elem) <one-norm one sum> { @vec.map({ abs($_) }).sum }
            when $_ (elem) <euclidean cosine two-norm two> { sqrt(sum(@vec <<*>> @vec)) }
            default { die "Unknown norm specification '$spec'."; }
        }
    }

    ##========================================================
    ## Normalize
    ##========================================================
    multi method normalize(Associative $mix, Str $spec = "euclidean") {
        $mix <<*>> safeInversion(self.norm($mix, $spec))
    }

    multi method normalize(@vec, Str $spec = 'euclidean') {
        @vec <<*>> safeInversion(self.norm(@vec, $spec))
    }
}
