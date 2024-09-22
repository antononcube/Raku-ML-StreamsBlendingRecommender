use ML::StreamsBlendingRecommender::AbstractSBR;
use ML::StreamsBlendingRecommender::UtilityFunctions;

class ML::StreamsBlendingRecommender::CompositeSBR
        is ML::StreamsBlendingRecommender::AbstractSBR
        does ML::StreamsBlendingRecommender::UtilityFunctions {

    ##========================================================
    ## Attributes
    ##========================================================
    has %!value;

    has ML::StreamsBlendingRecommender::AbstractSBR %.objects{Str} is rw = %();

    has Numeric %.weights{Str} is rw = %();

    ##========================================================
    ## Takers
    ##========================================================
    method take-objects() {
        %.objects
    }

    method take-value() {
        %!value
    }

    ## These are standard to have in the Composite design pattern,
    ## but I do not see the point of having them.
    #    multi method add(AbstractSBR $sbr, Str $name) {
    #        %.sbrs.append($name => $sbr);
    #        self
    #    }
    #
    #    multi method add(AbstractSBR $sbr, Str $name) {
    #        %.sbrs.append($name => $sbr);
    #        self
    #    }
    #
    #    method remove($name) {
    #        %.sbrs{$name}:delete;
    #        self
    #    }

    ##========================================================
    ## Recommend by history
    ##========================================================
    multi method recommend(@items, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True) {
        self.recommend(Mix(@items), $nrecs, :$normalize, :$object)
    }

    multi method recommend(Mix:D $items, Int:D $nrecs = 12, Bool :$normalize = False, Bool :$object = True) {
        ## It is not fast, but it is just easy to compute the profile and call recommend-by-profile.
        self.recommend-by-profile(Mix(self.profile($items).take-value), $nrecs, :$normalize, :$object)
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    multi method recommend-by-profile(@prof,
                                      Int:D $nrecs = 12,
                                      $normSpec is copy = Whatever,
                                      Bool :$normalize = False,
                                      Bool :$object = True) {
        self.recommend-by-profile(Mix(@prof), $nrecs, $normSpec, :$normalize, :$object)
    }

    multi method recommend-by-profile(Mix:D $prof,
                                      Int:D $nrecs = 12,
                                      $normSpec = Nil,
                                      Bool :$normalize = False,
                                      Bool :$object = True) {

        ## Fill-in weights
        my %recommenderWeights = %.weights;
        if (%recommenderWeights.elems > 0) {
            %recommenderWeights = Hash(%.objects.keys.map({ $_ => 1 })), %recommenderWeights;
        }

        ## Get recommendations from each object
        my %recs = do for %.objects.kv -> $name, $obj {
            $name => Mix($obj.recommend-by-profile($prof, $nrecs, :!normalize, :!object, :!warn))
        }

        ## Normalize each result by norm spec
        if $normSpec ~~ Str {
            %recs = %recs.map({ $_.key => self.normalize($_.value, $normSpec) })
        }

        ## Merge the recommendations
        my %resMix =
                do if %recommenderWeights.elems == 0 {
                    [(+)] %recs.values
                } else {
                    [(+)] %recs.values Z<<*>> %recommenderWeights{%recs.keys}
                };

        ## Normalize
        if $normalize { %resMix = self.normalize(%resMix, 'max-norm') }

        ## Sort
        my @res = %resMix.sort({ -$_.value });

        ## Result
        %!value = do if $nrecs < @res.elems { @res.head($nrecs) } else { @res };

        if $object { self } else { %!value }
    }

}
