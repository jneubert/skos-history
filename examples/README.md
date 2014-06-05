Dataset-specific examples
=========================

This directory hold examples which use the proposed architecture for custom
queries, which depend on the specifics of a certain dataset. E.g., the "Added
descriptors by category" example
([query](https://github.com/jneubert/skos-history/blob/master/examples/stw/added_by_category.rq),
[html result](https://rawgithub.com/jneubert/skos-history/master/examples/stw/added_by_category.html))
depends on the subject categories structure of STW Thesaurus for Economics (v8.10).

So while the examples will not run with other datasets, they may show how
value can be added by exploiting custom data structures, while at the same
time making use of a common version history scheme.

An [example rdfa page](stw/version_about.html) ([extracted triples](stw/version_about.ttl) enriches the current 
[STW version overview](http://zbw.eu/stw/versions) with data according to the proposed
[Dataset versioning vocabulary](https://github.com/JohanDS/Dataset-versioning--for-KOS-data-sets-). 
