GND subject headdings as SKOS vocabulary
=========================

The data for this very experimental application is extracted from the [GND Linked Data Service](http://www.dnb.de/EN/Service/DigitaleDienste/LinkedData/linkeddata_node.html), a dump of the German Integrated Authority File. It was restricted to the gndo:SubjectHeadingSensoStricto type, transformed to SKOS (via a [construct query]()) and complemented by the GND [subject categories]().

__Queries__

Query | Description
------|------------
[added_concepts_by_category](http://zbw.eu/beta/sparql-lab/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/sparql/swdskos/added_concepts_by_category.rq&endpoint=http://zbw.eu/beta/sparql/swdskosv/query&versionHistoryGraph=http://zbw.eu/beta/swdskos/version&language=de
) | Added GND concepts by subject category


