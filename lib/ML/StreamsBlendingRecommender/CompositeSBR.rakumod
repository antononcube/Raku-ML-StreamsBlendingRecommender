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
    method takeObjects() {
        %.objects
    }
    method takeValue() {
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
        ## It is not fast, but it is just easy to compute the profile and call recommendByProfile.
        self.recommendByProfile(Mix(self.profile($items).takeValue), $nrecs, :$normalize, :$object)
    }

    ##========================================================
    ## Recommend by profile
    ##========================================================
    multi method recommendByProfile(@prof, Int:D $nrecs = 12, $normSpec = Nil, Bool :$normalize = False,
                                    Bool :$object = True) {
        self.recommendByProfile(Mix(@prof), $nrecs, $normSpec, :$normalize, :$object)
    }

    multi method recommendByProfile(Mix:D $prof, Int:D $nrecs = 12, $normSpec = Nil,
                                    Bool :$normalize = False, Bool :$object = True) {

        my %recommenderWeights = %.weights;
        if ( %recommenderWeights.elems > 0 ) {
            %recommenderWeights = Hash(%.objects.keys.map({ $_ => 1 })) , %recommenderWeights;
        }

        ## Get recommendations from each object
        my %recs = do for %.objects.kv -> $name, $obj {
            $name => Mix($obj.recommendByProfile($prof, $nrecs, :!normalize, :!object, :!warn))
        }

        ## Normalize each result by norm spec
        if $normSpec {
            %recs = %recs.pairs.map({ self.normalize($_, $normSpec) })
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
