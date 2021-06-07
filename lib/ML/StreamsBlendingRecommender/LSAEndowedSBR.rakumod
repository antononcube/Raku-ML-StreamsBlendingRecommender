use ML::StreamsBlendingRecommender::AbstractSBR;
use ML::StreamsBlendingRecommender::CoreSBR;
use ML::StreamsBlendingRecommender::LSATopicSBR;
use ML::StreamsBlendingRecommender::UtilityFunctions;

class ML::StreamsBlendingRecommender::LSAEndowedSBR
        is ML::StreamsBlendingRecommender::AbstractSBR
        does ML::StreamsBlendingRecommender::UtilityFunctions {

    ##========================================================
    ## Recommender object
    ##========================================================

    has ML::StreamsBlendingRecommender::CoreSBR $.Core is rw = Nil;
    has ML::StreamsBlendingRecommender::LSATopicSBR $.LSA is rw = Nil;

    ##========================================================
    ## Recommend by profile delegation
    ##========================================================
    multi method recommendByProfile($prof,
                                    Int:D $nrecs = 12,
                                    Bool :$normalize = False,
                                    Bool :$object = True,
                                    Bool :$warn) {
        ## Check
        if not self.Core.defined {
            warn "No Core SBR object.";
            return Nil
        }

        self.Core.recommendByProfile($prof, $nrecs, :$normalize, :$object, :$warn)
    }

    ##========================================================
    ## Recommend by profile and text
    ##========================================================
    multi method recommendByProfile(@prof,
                                    Str:D $text,
                                    Int:D $nrecs = 12,
                                    Bool :$normalize = False,
                                    Bool :$object = True,
                                    Bool :$warn = True) {
        self.recommendByProfile(Mix(@prof), $text, $nrecs, :$normalize, :$object, :$warn)
    }

    multi method recommendByProfile(Mix $prof,
                                    Str:D $text,
                                    Int:D $nrecs = 12,
                                    Bool :$normalize = False,
                                    Bool :$object = True,
                                    Bool :$warn = True,
                                    Str :$profileNormalizer = 'eucliden' ) {

        ## Check
        if not self.Core.defined {
            warn "No Core SBR object.";
            return Nil
        }

        if not self.LSA.defined {
            warn "No LSA SBR object.";
            return Nil
        }

        if not ( $prof.defined or $text.defined ) {
            warn 'Empty profile and text.';
            return Nil
        }

        ## Make a profile corresponding to the text.
        my %textProf;
        if $text.chars > 0 {
            ## Represent by terms.
            my Mix $textWordsProf = Mix( self.LSA.representByTerms($text, :normalize, :!object) );

            ## Represent by topics.
            my Mix $textTopicsProf = Mix( self.LSA.representByTopics($text, :normalize, :!object) );

            ## Appropriate verifications have to be made for concatenating with 'Word:' and 'Topic:'.
            $textWordsProf = $textWordsProf.map({ 'Word:' ~ $_.key => $_.value }).Mix;
            $textTopicsProf = $textTopicsProf.map({ 'Topic:' ~ $_.key => $_.value }).Mix;

            $textWordsProf = self.normalize($textWordsProf, :$profileNormalizer);
            $textTopicsProf = self.normalize($textTopicsProf, :$profileNormalizer);

            ## Make the word-topics profile.
            %textProf = $textWordsProf (|) $textTopicsProf;
        }

        ## Make the combined profile.
        ## Note, the additional normalization arguments have to be surfaced to the signature.
        my $profCombined =
                do with $prof.defined { self.normalize($prof, :$profileNormalizer) (|) %textProf }
                else { %textProf }

        ## Get recommendations
        self.Core.recommendByProfile( $profCombined, $nrecs, :$normalize, :$object, :$warn)
    }

}
