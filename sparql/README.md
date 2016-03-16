SPARQL queries
==============

The queries linked from this page provide examples on how a skos-history version store can be utilized to create useful change reports. The queries can be executed via an [interactive SPARQL GUI](http://zbw.eu/labs/en/blog/publishing-sparql-queries-live) against an [example endpoint](http://zbw.eu/beta/sparql/stwv/query) with different versions of [STW Thesaurus for Economics](http://zbw.eu/stw), prepared as s skos-history version store acccording to [Versions and Deltas as Named Graphs](https://github.com/jneubert/skos-history/wiki/Versions-and-Deltas-as-Named-Graphs).


## Generic queries for any SKOS vocabulary

__Overview__

| Query | Description |
|-------|-------------|
| [version_overview](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq) | Discover the version history graph and all available scheme versions |

__Lists of concepts__

| Query | Description |
|-------|-------------|
[added_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/added_concepts.rq) | Identify all concepts inserted in the current version
[added_concepts_with_top_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/added_concepts_with_top_concepts.rq) | Identify all concepts inserted in the current version with their top concepts
[labels_moved_to_added_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/labels_moved_to_added_concepts.rq) | Show the labels which have moved to newly inserted concepts (flag new concepts if subordinated to the old one)
[deprecated_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/deprecated_concepts.rq)  | Identify all concepts deprecated with the current version
[deleted_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/deleted_concepts.rq)  | Identify all concepts deleted with the current version
[changed_notations](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/changed_notations.rq) | For a classification (in this case the subject categories of STW), show which notation has changed

__Aggregated information about versions__

| Query | Description |
|-------|-------------|
| [count_added_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_added_concepts.rq) | Count concepts inserted per version |
| [count_deleted_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_deleted_concepts.rq) | Count concepts deleted per version |
| [count_deprecated_concepts](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_deprecated_concepts.rq) | Count concepts deprecated per version |
| [count_added_labels](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_added_labels.rq) | Count added alt/prefLabels in a certain language per version (may include formal changes, e.g. re capitalization) |
| [count_deleted_labels](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_deleted_labels.rq) | Count deleted alt/prefLabels in a certain language per version (may include formal changes, e.g. re capitalization) |

__History of selected concepts__

| Query | Description |
|-------|-------------|
| [concept_deltas](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/concept_deltas.rq) | All version deltas for the concept [Personnel selection](http://zbw.eu/stw/descriptor/12571-4) _(Insert other example concept uris into the VALUES clause - suggestions in the comment.)_ |
| [concept_history](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/concept_history.rq) | Early alternative approach for the history of the concept [Personnel selection](http://zbw.eu/stw/descriptor/12571-4) (changes in pref/altLabels only) |

__Technical background information__

| Query | Description |
|-------|-------------|
| [version_graph](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_graph.rq) | Complete version history graph |
| [service_graph](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/service_graph.rq) | Complete service description graph (default graph) |

__Extension to SKOS-XL__

Some of the example queries have been adapted to work against version of thesauri, which uses [SKOS-XL](http://www.w3.org/TR/skos-reference/skos-xl.html). The queries can be directed to the thesoz or agrovoc example endpoints (see below).


## Dataset-specific queries

More often than not, SKOS publications contain information specific to the dataset in question. Dataset-specific queries may exploit and expose this additional information.

- [STW Thesaurus for Economics](stw) (beta)
- [GND subject headings](swdskos) (experimental)

So while the examples will not run with other datasets, they may show how
value can be added by exploiting custom data structures, while at the same
time making use of a common version history scheme.


## Further (purely experimental) skos-history example endpoints

- TheSoz - add `&endpoint=http://zbw.eu/beta/sparql/thesozv/query` to the URL<br />([version overview](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq&endpoint=http://zbw.eu/beta/sparql/thesozv/query&versionHistoryGraph=http://lod.gesis.org/thesoz/version) - `?versionHistoryGraph` is `http://lod.gesis.org/thesoz/version`)
- YSO - add `&endpoint=http://zbw.eu/beta/sparql/ysov/query` to the URL<br />([version overview](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq&endpoint=http://zbw.eu/beta/sparql/ysov/query&versionHistoryGraph=http://www.yso.fi/onto/yso/version) - `?versionHistoryGraph` is `http://www.yso.fi/onto/yso/version`)
- Agrovoc - add `&endpoint=http://zbw.eu/beta/sparql/agrovocv/query` to the URL<br />([version overview](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq&endpoint=http://zbw.eu/beta/sparql/agrovocv/query&versionHistoryGraph=http://aims.fao.org/aos/agrovoc/version) - `?versionHistoryGraph` is `http://aims.fao.org/aos/agrovoc/version`)
- GND subject headings - add `&endpoint=http://zbw.eu/beta/sparql/swdskosv/query&language=de` to the URL<br />([version overview](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq&endpoint=http://zbw.eu/beta/sparql/swdskosv/query&versionHistoryGraph=http://zbw.eu/beta/swdskos/version) - `?versionHistoryGraph` is `http://zbw.eu/beta/swdskos/version`)

