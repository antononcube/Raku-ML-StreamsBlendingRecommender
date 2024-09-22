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
    #| Recommend by profile delegation. (To the C<$.Core> attribute.)
    #| * C<@prof> A list or a mix of tags.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend-by-profile($prof,
                                      Int:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Bool :$object = True,
                                      Bool :$warn) {
        ## Check
        if not self.Core.defined {
            warn "No Core SBR object.";
            return Nil
        }

        self.Core.recommend-by-profile($prof, $nrecs, :$normalize, :$object, :$warn)
    }

    ##========================================================
    ## Recommend by profile and text
    ##========================================================
    #|  Recommend by profile and text.
    #| * C<@prof> Profile tags.
    #| * C<$text> Text query.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$profileNormalizer> Profile normalizer spec.
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend-by-profile(@prof,
                                      Str:D $text,
                                      Int:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Str :$profileNormalizer = 'euclidean',
                                      Bool :$object = True,
                                      Bool :$warn = True) {
        self.recommend-by-profile(Mix(@prof), $text, $nrecs, :$normalize, :$profileNormalizer, :$object, :$warn)
    }

    #|  Recommend by profile and text.
    #| * C<$prof> Scored tags profile.
    #| * C<$text> Text query.
    #| * C<$nrecs> Number of recommendations.
    #| * C<$normalize> Should the recommendation scores be normalized or not?
    #| * C<$profileNormalizer> Profile normalizer spec.
    #| * C<$object> Should the result be an object or not?
    #| * C<$warn> Should warnings be issued or not?
    multi method recommend-by-profile(Mix $prof,
                                      Str:D $text,
                                      Int:D $nrecs = 12,
                                      Bool :$normalize = False,
                                      Str :$profileNormalizer = 'euclidean',
                                      Bool :$object = True,
                                      Bool :$warn = True) {

        ## Check
        if not self.Core.defined {
            warn "No Core SBR object.";
            return Nil
        }

        if not self.LSA.defined {
            warn "No LSA SBR object.";
            return Nil
        }

        if not ($prof.defined or $text.defined) {
            warn 'Empty profile and text.';
            return Nil
        }

        ## Make a profile corresponding to the text.
        my %textProf;
        if $text.chars > 0 {
            ## Represent by terms.
            my Mix $textWordsProf = Mix(self.LSA.represent-by-terms($text, :normalize, :!object));

            ## Represent by topics.
            my Mix $textTopicsProf = Mix(self.LSA.represent-by-topics($text, :normalize, :!object));

            ## Appropriate verifications have to be made for concatenating with 'Word:' and 'Topic:'.
            $textWordsProf = $textWordsProf.map({ 'Word:' ~ $_.key => $_.value }).Mix;
            $textTopicsProf = $textTopicsProf.map({ 'Topic:' ~ $_.key => $_.value }).Mix;

            ## Normalize each profile
            $textWordsProf = self.normalize($textWordsProf, :$profileNormalizer);
            $textTopicsProf = self.normalize($textTopicsProf, :$profileNormalizer);

            ## Make the words-and-topics profile.
            %textProf = $textWordsProf (|) $textTopicsProf;
        }

        ## Make the combined profile.
        ## Note, the additional normalization arguments have to be surfaced to the signature.
        my $profCombined =
                do with $prof.defined { self.normalize($prof, :$profileNormalizer) (|) %textProf }
                else { self.normalize(%textProf, :$profileNormalizer) }

                ## Get recommendations
        self.Core.recommend-by-profile($profCombined, $nrecs, :$normalize, :$object, :$warn)
    }

}
