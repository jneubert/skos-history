SPARQL query examples
=====================

The queries in this directory can be executed via an <strong>interactive SPARQL GUI</strong> (powered by <a href="http://yasqe.yasgui.org">YASQUE</a> and <a href="http://yasr.yasgui.org/">YASR</a>) against an <a href="http://zbw.eu/beta/sparql/stwv/query">example endpoint</a> with diffent versions of [STW Thesaurus for Economics](http://zbw.eu/stw), prepared acccording to [Versions and Deltas as Named Graphs](https://github.com/jneubert/skos-history/wiki/Versions-and-Deltas-as-Named-Graphs):

__Aggregated information about versions__

| Query | Description |
|-------|-------------|
| [version_overview](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_overview.rq) | All available scheme versions |
| [count_added_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_added_concepts.rq) | Count concepts inserted per version |
| [count_deleted_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_deleted_concepts.rq) | Count concepts deleted per version |
| [count_deprecated_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/count_deprecated_concepts.rq) | Count concepts deprecated per version |

__Lists of concepts__

| Query | Description |
|-------|-------------|
| [added_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/added_concepts.rq) | Identify all concepts inserted in the current version |
| [added_concepts_with_top_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/added_concepts_with_top_concepts.rq) | Identify all concepts inserted in the current version with their top concepts |
| [deprecated_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/deprecated_concepts.rq)  | Identify all concepts deprecated with the current version  |
| [deleted_concepts](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/deleted_concepts.rq)  | Identify all concepts deleted with the current version  |

__History of selected concepts__

| Query | Description |
|-------|-------------|
| [concept_history](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/concept_history.rq) | History of the concept [Personnel selection](http://zbw.eu/stw/descriptor/12571-4) (changes in pref/altLabels) |
| [concept_deltas] | All version deltas for the concept [Personnel selection](http://zbw.eu/stw/descriptor/12571-4) |


__Technical background information__

| Query | Description |
|-------|-------------|
| [version_graph](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/version_graph.rq) | Complete version history graph |
| [service_graph](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/service_graph.rq) | Complete service description graph (default graph) |

