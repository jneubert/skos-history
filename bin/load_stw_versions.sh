#!/bin/sh
# nbt, 1.9.2013

# load a series of graphs and deltas into a fuseki dataset

BASEDIR=/opt/thes/var/stw
VERSIONS=(8.04 8.06 8.08 8.10)
ENDPOINT=http://localhost:3030/stwv
BASEURI=http://zbw.eu/stw/version
PREFIXES="
prefix : <http://zbw.eu/namespaces/skos-history/> 
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> 
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> 
prefix owl: <http://www.w3.org/2002/07/owl#> 
prefix xsd: <http://www.w3.org/2001/XMLSchema#> 
prefix dc: <http://purl.org/dc/elements/1.1/> 
prefix dcterms: <http://purl.org/dc/terms/> 
prefix skos: <http://www.w3.org/2004/02/skos/core#> 
"

# load latest version to the default graph
latest=${VERSIONS[${#VERSIONS[@]} - 1]}
printf "\nLoading latest version $latest to default graph\n"
$FUSEKI_HOME/s-put $ENDPOINT/data default $BASEDIR/$latest/rdf/stw.nt


# iterate over the versions, create and load the deltas
for index in ${!VERSIONS[*]}
do
  old=${VERSIONS[$index]}

  # load the version graph
  printf "\nLoading $BASEURI/$old\n"
  $FUSEKI_HOME/s-put $ENDPOINT/data $BASEURI/$old $BASEDIR/$old/rdf/stw.nt

  # add triples to the version graph
  # (particularly frbrer is Realization Of
  statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$BASEURI/$old> a :SchemeVersion .
  <$BASEURI/$old> <http://iflastandards.info/ns/fr/frbr/frbrer/P2002> <http://zbw.eu/stw> .
  <$BASEURI/$old> <http://purl.org/dc/terms/isVersionOf> <http://zbw.eu/stw> .
}
where {}
"
  $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

  # add triples to the default graph
  statement="  
$PREFIXES
insert {
  <$BASEURI/$old> a :SchemeVersion .
  <http://zbw.eu/stw> <http://purl.org/dc/terms/hasVersion> <$BASEURI/$old>
}
where {}
"
  $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
done

# do a second pass, to avoid triples being overridden by version loading
for index in ${!VERSIONS[*]}
do
  old=${VERSIONS[$index]}
  new=${VERSIONS[$index+1]}


  # skip deltas, if no new version exists
  if [ $new ]; then
    delta_uri=$BASEURI/$old/delta/$new
    printf "\nCreating and loading $delta_uri\n"

    filebase=/tmp/stw_${old}_${new}
    diff=$filebase.diff

    # create the diff
    rdf diff $BASEDIR/$old/rdf/stw.nt $BASEDIR/$new/rdf/stw.nt > $diff

    # split into delete and insert files (filtering out blank nodes)
    grep '^< ' $diff | egrep -v "(^_:|> _:)" | sed 's/^< //' > ${filebase}_deletions.nt
    grep '^> ' $diff | egrep -v "(^_:|> _:)" | sed 's/^> //' > ${filebase}_insertions.nt

    # add triples to default graph
    statement="
$PREFIXES
insert {
  <http://zbw.eu/stw> <http://zbw.eu/namespaces/skos-history/hasDelta> <$delta_uri> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaFrom> <$BASEURI/$old> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaTo> <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
    # add triples to old version graph
    statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$BASEURI/$old> <http://zbw.eu/namespaces/skos-history/hasDelta> <$delta_uri> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaFrom> <$BASEURI/$old> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaTo> <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
    # add triples to old version graph
    statement="
$PREFIXES
with <$BASEURI/$new>
insert {
  <$BASEURI/$new> <http://zbw.eu/namespaces/skos-history/hasDelta> <$delta_uri> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaFrom> <$BASEURI/$old> .
  <$delta_uri> <http://zbw.eu/namespaces/skos-history/deltaTo> <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

    # load delta
    for op in deletions insertions; do

      # load file
      $FUSEKI_HOME/s-put $ENDPOINT/data $delta_uri/$op ${filebase}_$op.nt

      echo add triples to the delta graph for $op
      statement="
$PREFIXES
with <$delta_uri/$op>
insert {
  <$delta_uri/$op> a :SchemeDelta${op^} .
  <$delta_uri/$op> <http://purl.org/dc/terms/isPartOf> <$delta_uri> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
      echo add triples to both version graphs for $op
      statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$delta_uri/$op> a :SchemeDelta${op^} .
  <$delta_uri> <http://purl.org/dc/terms/hasPart> <$delta_uri/$op> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
      statement="
$PREFIXES
with <$BASEURI/$new>
insert {
  <$delta_uri/$op> a :SchemeDelta${op^} .
  <$delta_uri> <http://purl.org/dc/terms/hasPart> <$delta_uri/$op> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

    done
  fi
done
