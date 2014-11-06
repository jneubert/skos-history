Dataset-specific examples
=========================

This directory hold examples which use the proposed architecture for custom
queries, which depend on the specifics of a certain dataset. E.g., the [Added
descriptors by
category](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/examples/stw/sparql/added_by_category.rq)
query depends on the subject categories structure of STW Thesaurus for
Economics (current version v8.12).

So while the examples will not run with other datasets, they may show how
value can be added by exploiting custom data structures, while at the same
time making use of a common version history scheme.

The dataset versioning approach is experimentally applied to a STW versions
RDFa page at [stw/rdfa](stw/rdfa).


STW
---

Query | Description
------|------------
[count_added_by_category](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/examples/stw/sparql/count_added_by_category.rq) | Count added STW concepts by second-level category
[added_by_category](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/examples/stw/sparql/added_by_category.rq) | Added STW concepts by second-level category
[added_labels](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/examples/stw/sparql/added_labels.rq) | Added descriptor labels (pref/altLabels)
[deleted_labels](http://zbw.eu/beta/sparql-gui/?queryRef=https://api.github.com/repos/jneubert/skos-history/contents/examples/stw/sparql/deleted_labels.rq) | Deleted descriptor labels (pref/altLabels)

