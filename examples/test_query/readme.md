
This example is based on the assumption that there is a SPARQL enpoint available running on the localhost. The example has been tested with Fuseki server with an empty repository "test" available.   

To load two versions of the test dataset (a manually picked fragment from EuroVoc) run the command line provided below.  

```
../../bin/load_versions.sh -f ./test.config
```

To run the diff SPARQL queries checking for basic SKOS core properties run the command line provided below. The queries have been generated automatically using [this script](https://github.com/eu-vocabularies/skos-history-query-generator).

```
../../bin/run_queries.sh -f ./test.config
```   

After the script finished running check the ./data/output folder to see the SPARQL query result sets containing the SKOS core diffs.     
