# Raku Streams Blending Recommender

Raku implementation of a Streams Blending Recommender (SBR) framework.

Based on the article [AA1].

## TODO

- [ ] LSA-FE (Latent Semantic Analysis Feature Extractor) that inherits SBR

- [ ] Application of the Composite Design Pattern

- [ ] Parameters for specifying which columns to expect in data ingestion

- [ ] More extensive results verification and failure management

- [ ] Adverbs for methods
   
  - [ ] Should the object be returned, or the computation result?
  - [ ] Should the recommendation results be normalized or not?  
  
- [ ] Unit tests

  - [ ] Decide which/what data to use
  - [ ] Data ingestion tests
  - [ ] Core functionalities tests
  - [ ] Normalization tests
  - [ ] Annexing of recommenders tests
  - [ ] Composite SBR tests  
    
- [ ] Annex method
 
   - [ ] For another SBR object
   - [ ] For a collection of inverse indexes
    
- [ ] Class and method pod6 documentation

- [ ] Full-blown documentation of recomemndations computation using hash maps (Raku `Mix`es)

  - [ ] Decide on example data
  - [ ] Core algorithm
  - [ ] LSA topic extraction
  - [ ] Merging of results from different recommenders


## References

[AA1] Anton Antonov, 
["Mapping Sparse Matrix Recommender to Streams Blending Recommender"](https://github.com/antononcube/MathematicaForPrediction/tree/master/Documentation/MappingSMRtoSBR), 
(2019),
[GitHub/antononcube](https://github.com/antononcube)

