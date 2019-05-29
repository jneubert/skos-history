skos-history
============

"What's new?" and "What has changed?" are common user questions when a new version of a SKOS vocabulary is published.

This project tries to take advantage of the regular structure of SKOS files to make these questions answerable for both non-geeky humans and machines. To this end, an ontology/application profile, a set of processing practices and supporting code are developed.

The use cases to be covered are discussed in [List of Use Cases](https://github.com/jneubert/skos-history/wiki/List-of-Use-Cases), the [List of Change Categories](https://github.com/jneubert/skos-history/wiki/List-of-Change-Categories) and in the [issue queue](https://github.com/jneubert/skos-history/issues?state=open).

[Versions and Deltas as Named Graphs](https://github.com/jneubert/skos-history/wiki/Versions-and-Deltas-as-Named-Graphs) are introduced as an approach to provide the infrastructure to these ends. [SPARQL queries](https://github.com/jneubert/skos-history/tree/master/sparql) can be applied to an example version store created according to this approach, and can be modified for own explorations. A [tutorial](https://github.com/jneubert/skos-history/wiki/Tutorial) describes how to apply this approach to arbitrary SKOS vocabularies, using the code provided here. 

The [skos-history ontology](http://purl.org/skos-history/) is meant to be used in combination with the [dataset versioning ontology](http://www.essepuntato.it/lode/owlapi/https://raw.githubusercontent.com/JohanDS/Dataset-versioning--for-KOS-data-sets-/master/DataSetVersioning.owl) - both being work in progress.

See also the [Ontologies, Thesauri, Vocabularies](https://github.com/jneubert/skos-history/wiki/Ontologies-Thesauri-Vocabularies) and the [Resources](https://github.com/jneubert/skos-history/wiki/Resources) sections.

A tool that automatically generates the SPARQL queries for diffing various SKOS profiles is available at [EU Vocabularies repository](https://github.com/eu-vocabularies/skos-history-query-generator).

### Contributing

Contributions are very much appreciated - be it in the form of suggestions or bug reports in the [issue queue](https://github.com/jneubert/skos-history/issues), or as patches or pull requests for improved or additional queries or script code. This in particular includes extensions to cover the specifics of not yet well-supported SKOS vocabularies.

