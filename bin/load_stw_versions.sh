#!/bin/sh
# nbt, 1.9.2013

# load a series of version and delta graphs into a SPARQL 1.1 RDF dataset


# Requirements:

# Redland's rapper and rdf.sh`s rdf command should be in $PATH


# START CONFIGURATION

DATASET=stwv

# is used to store the SKOS files locally
#BASEDIR=/opt/thes/var/stw
BASEDIR=/tmp/stw_versions
FILENAME=rdf/stw.nt

# publicly available STW versions
##VERSIONS=(8.04 8.06 8.08 8.10 8.12)
VERSIONS=(8.08 8.10 8.12)
SCHEMEURI='http://zbw.eu/stw'

# implementation-specific uris
#IMPL='sesame'
IMPL='fuseki'
if [ $IMPL == "sesame" ]; then
  ENDPOINT=http://localhost:8080/openrdf-sesame/repositories/$DATASET
  PUT_URI=$ENDPOINT/rdf-graphs/service
  UPDATE_URI=$ENDPOINT/statements
  QUERY_URI=$ENDPOINT
elif [ $IMPL == "fuseki" ]; then
  ENDPOINT=http://localhost:3030/$DATASET
  PUT_URI=$ENDPOINT/data
  UPDATE_URI=$ENDPOINT/update
  QUERY_URI=http://zbw.eu/beta/sparql/stwv/query
else
  echo implementation $IMPL not defined
  exit
fi

# END CONFIGURATION

sparql_put()
{
  curl -X PUT -H "Content-Type: application/x-turtle" -d @$2 $PUT_URI?graph=$1
}

sparql_update()
{
  # suppress output of returned HTML (in case of fuseki)
  curl -X POST --silent -d "update=$1" $UPDATE_URI > /dev/null
}

# handle trailing slash in scheme uri
if [ "${SCHEMEURI: -1}" == "/" ]; then
  BASEURI=${SCHEMEURI}version
else
  BASEURI=$SCHEMEURI/version
fi
SPARQL_DDDURI=$BASEURI/sparq-service/ddd

PREFIXES="
prefix : <http://raw.github.com/jneubert/skos-history/master/skos-history.ttl/>
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix dcterms: <http://purl.org/dc/terms/>
prefix dsv: <http://purl.org/iso25964/DataSet/Versioning#>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix sd: <http://www.w3.org/ns/sparql-service-description#>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix void: <http://rdfs.org/ns/void#>
prefix xhv: <http://www.w3.org/1999/xhtml/vocab#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>
"

# create a SPARQL service description in the default graph
SERVICE_URI=$BASEURI/sparq-service
SERVICE_DDDURI=$SERVICE_URI/ddd
statement="
$PREFIXES
insert {
<$SERVICE_URI> a sd:Service;
    sd:url <$QUERY_URI>;
    sd:defaultDatasetDescription <$SERVICE_DDDURI> .
<$SERVICE_DDDURI> a sd:Dataset;
    dcterms:title \"STW Versions SPARQL Service\";
    sd:defaultGraph [
        a sd:Graph;
        dcterms:title \"STW Versions SPARQL Service Description\";
    ] .
}
where {}
"
sparql_update "$statement"

# getting the data from http://zbw.eu/stw, if it does not exist locally
for index in ${!VERSIONS[*]}
do
  version=${VERSIONS[$index]}
  dir=$BASEDIR/$version
  file=$dir/$FILENAME
  if [ ! -f $file ]; then
    echo "downloading $download_url"
    mkdir -p $dir/rdf
    download_url="http://zbw.eu/stw/versions/$version/download/stw.rdf.zip"
    download_file="$dir/rdf/stw.rdf.zip"
    wget -O $download_file $download_url
    unzip -d $dir/rdf $download_file
    rapper -i guess $dir/rdf/stw.rdf > $file
    rm $download_file $dir/rdf/stw.rdf
  fi
done

# load latest version to the version history  graph
latest=${VERSIONS[${#VERSIONS[@]} - 1]}
echo Creating version history
statement="
$PREFIXES
with <$BASEURI>
insert {
  <$BASEURI> a dsv:VersionHistorySet ;
      :isVersionHistoryOf <$SCHEMEURI> ;
      dsv:currentVersionRecord <${BASEURI}record/$latest> ;
      void:sparqlEndpoint <$QUERY_URI> ;
      :usingNamedGraph <$BASEURI/ng> .
  <$BASEURI/ng> a sd:NamedGraph ;
      sd:name <$BASEURI> .
}
where {}
"
sparql_update "$statement"

# complement service description
statement="
$PREFIXES
insert {
  <$SERVICE_DDDURI> sd:namedGraph <$BASEURI/ng> .
  <$BASEURI/ng> a sd:NamedGraph ;
      sd:name <$BASEURI> .
}
where {}
"
sparql_update "$statement"

# iterate over the versions, create and load the deltas
for index in ${!VERSIONS[*]}
do
  old=${VERSIONS[$index]}

  # load the version graph
  printf "\nLoading $BASEURI/$old\n"
  sparql_put $BASEURI/$old $BASEDIR/$old/$FILENAME

  # add triples to the version graph
  # (particularly frbrer is Realization Of)
  statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$BASEURI/$old> <http://iflastandards.info/ns/fr/frbr/frbrer/P2002> <$SCHEMEURI> .
  <$SCHEMEURI> dsv:hasVersionRecord <${BASEURI}record/$latest> ;
      :hasVersionHistory <$BASEURI> .
}
where {}
"
  sparql_update "$statement"

  # add triples to the version history graph
  # (fix invalid string date format for older stw versions)
  statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$old>
      a dsv:VersionHistoryRecord ;
      dsv:hasVersionHistorySet <${BASEURI}> ;
      dsv:isVersionRecordOf <$BASEURI/$old/download/stw.rdf.zip> ;
      dsv:isVersionRecordOf <$BASEURI/$old/download/stw.ttl.zip> ;
      dsv:isVersionRecordOf <$BASEURI/$old/ng> ;
      :usingNamedGraph <$BASEURI/$old/ng> ;
      dc:date ?fixeddate;
      dc:identifier ?identifier .
  <$BASEURI/$old/ng> a sd:NamedGraph ;
      sd:name <$BASEURI/$old> .
}
where {
  GRAPH <$BASEURI/$old> {
    <$SCHEMEURI> dcterms:issued ?date ;
        owl:versionInfo ?identifier .
    BIND(coalesce(strdt(?date, xsd:date), ?date) as ?fixeddate)
  }
}
"
  sparql_update "$statement"

  # complement service description
  statement="
$PREFIXES
insert {
  <$SERVICE_DDDURI> sd:namedGraph <$BASEURI/$old/ng> .
  <$BASEURI/$old/ng> a sd:NamedGraph ;
      sd:name <$BASEURI/$old> .
}
where {}
"
      sparql_update "$statement"

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

    filebase=$BASEDIR/${old}_${new}
    diff=$filebase.diff

    # create the diff
    rdf diff $BASEDIR/$old/$FILENAME $BASEDIR/$new/$FILENAME > $diff

    # split into delete and insert files (filtering out blank nodes)
    grep '^< ' $diff | egrep -v "(^_:|> _:)" | sed 's/^< //' > ${filebase}_deletions.nt
    grep '^> ' $diff | egrep -v "(^_:|> _:)" | sed 's/^> //' > ${filebase}_insertions.nt

    # add triples to version history graph
    statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$old> :hasDelta <$delta_uri> .
  <${BASEURI}record/$new> :hasDelta <$delta_uri> ;
      xhv:prev <${BASEURI}record/$old> .
  <$delta_uri> a :SchemeDelta ;
      :deltaFrom <${BASEURI}record/$old> ;
      :deltaTo <${BASEURI}record/$new> .
}
where {}
"
    sparql_update "$statement"

    # load delta
    for op in deletions insertions; do

      # make variable with first character uppercased
      op_var="$(tr '[:lower:]' '[:upper:]' <<< ${op:0:1})${op:1}"

      # load file
      sparql_put $delta_uri/$op ${filebase}_$op.nt

      echo add triples to the version graph for $op
      statement="
$PREFIXES
with <$BASEURI>
insert {
  <$delta_uri> dcterms:hasPart <$delta_uri/$op> .
  <$delta_uri/$op> a :SchemeDelta$op_var ;
      dcterms:isPartOf <$delta_uri> ;
      :usingNamedGraph <$delta_uri/$op/ng> .
  <$delta_uri/$op/ng> a sd:NamedGraph ;
      sd:name <$delta_uri/$op> .
}
where {}
"
      sparql_update "$statement"

      # complement service description
      statement="
$PREFIXES
insert {
  <$SERVICE_DDDURI> sd:namedGraph <$delta_uri/$op/ng> .
  <$delta_uri/$op/ng> a sd:NamedGraph ;
      sd:name <$delta_uri/$op> .
}
where {}
"
      sparql_update "$statement"

    done

    # cleanup
    /bin/rm $filebase*
  fi
done
