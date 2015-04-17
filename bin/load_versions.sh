#!/bin/bash
# nbt, 1.9.2013

# load a series of version and delta graphs into a SPARQL 1.1 RDF dataset


## Help text
usage ()
{
  echo "usage: load_versions.sh [[-f file ] | [-h]]"
  echo "examples: load_versions.sh -f yso.config"
  echo "NOTE: the directory of the file needs to be in PATH or the path should be explicit"
}

## Read configuration

# demands 1 or 2 command-line arguments
if [ $# -lt 1 -o $# -gt 2 ]
then
  usage
  exit 1
fi

# Handling the command line arguments
# Get the configure file path
while [ "$1" != "" ]; do
  case $1 in
    -f | --file )           shift
                            configfile=$1
                            ;;
    -h | --help )           usage
                            exit
                            ;;
    * )                     usage
                            exit 1
  esac
  shift
done

# reading in the stored variablesb from the configuration file
. $configfile


#######################
# function definitions
#######################

sparql_put()
{
  curl -X PUT -H "Content-Type: application/x-turtle" -d @$2 $PUT_URI?graph=$1
}

sparql_update()
{
  # suppress output of returned HTML (in case of fuseki)
  curl -X POST --silent -d "update=$1" $UPDATE_URI > /dev/null
}

load_version () {

  # parameter check
  if [ -z "$1" ]; then
    echo "function must be called with \$version parameter"
    exit
  else
    version=$1
  fi

  # load the version graph
  printf "\nLoading $BASEURI/$version\n"
  sparql_put $BASEURI/$version $BASEDIR/$version/$FILENAME

  # add triples to the version graph
  # (particularly frbrer is Realization Of)
  statement="
$PREFIXES
with <$BASEURI/$version>
insert {
  <$BASEURI/$version> <http://iflastandards.info/ns/fr/frbr/frbrer/P2002> <$SCHEMEURI> .
  <$SCHEMEURI> dsv:hasVersionRecord <${BASEURI}record/$latest> ;
      :hasVersionHistorySet <$BASEURI> .
}
where {}
"
  sparql_update "$statement"

  # add triples to the version history graph
  # (fix invalid string date format for thesoz and for older stw versions)
  statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$version>
      a dsv:VersionHistoryRecord ;
      dsv:hasVersionHistorySet <${BASEURI}> ;
      dsv:isVersionRecordOf <$BASEURI/$version/download/$DATASET.rdf.zip> ;
      dsv:isVersionRecordOf <$BASEURI/$version/download/$DATASET.ttl.zip> ;
      dsv:isVersionRecordOf <$BASEURI/$version/ng> ;
      :usingNamedGraph <$BASEURI/$version/ng> ;
      dc:date ?fixedDate ;
      dc:identifier ?fixedIdentifier .
  <$BASEURI/$version/ng> a sd:NamedGraph ;
      sd:name <$BASEURI/$version> .
}
where {
  GRAPH <$BASEURI/$version> {
    # compute identifier (fix missing if necessary)
    # stw and recent thesoz version property
    OPTIONAL {
      <$SCHEMEURI> owl:versionInfo ?identifier
      # avoid using SVN-generated version strings in e.g. old YSA versions
      FILTER (!CONTAINS(?identifier, '$'))
    } .
    # old thesoz version prpoperty
    OPTIONAL { <$SCHEMEURI> dcterms:hasVersion ?identifier } .
    # otherwise, use $version
    BIND (coalesce(?identifier, \"$version\") as ?fixedIdentifier)

    # compute date as xsd:date (fix if necessary -
    # date values may occur as string, xsd:date or xsd:dateTime;
    # strings may take the form of 'yyyy/mm/dd' (thesoz 0.7) or 'yyyy-mm-ddThh:mm:ssZ'

    # stw uses dcterms:issued (string or xsd:date)
    OPTIONAL {
      <$SCHEMEURI> dcterms:issued ?issued .
    }
    # thesoz et al. use dcterms:modified (in case of thesoz, plus dcterms:issued for created date)
    OPTIONAL {
      <$SCHEMEURI> dcterms:modified ?modified .
    }
    BIND (str(coalesce(?modified, ?issued)) as ?someStr)
    BIND (concat(substr(?someStr, 1, 4), '-', substr(?someStr, 6, 2), '-', substr(?someStr, 9, 2)) as ?dateStr)
    BIND (strdt(?dateStr, xsd:date) as ?fixedDate)
  }
}
"
  sparql_update "$statement"

  # special clause for thesauri which have no unique
  # version date in the data and are enumerated in $VERSIONS by a valid date
  VERSION_DATE_MISSING=(agrovoc)
  if [[ $VERSION_DATE_MISSING =~ $DATASET ]] ; then
    # delete multiple entries, as provided by agrovoc
    statement="
$PREFIXES
with <$BASEURI>
delete {
  <${BASEURI}record/$version> dc:date ?x .
}
where {
  <${BASEURI}record/$version> dc:date ?x .
}
"
    sparql_update "$statement"

    # insert triple constructed from version string
    statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$version> dc:date \"$version\"^^xsd:date .
}
where {}
"
    sparql_update "$statement"
  fi

  # complement service description
  statement="
$PREFIXES
insert {
  <$SERVICE_DDURI> sd:namedGraph <$BASEURI/$version/ng> .
  <$BASEURI/$version/ng> a sd:NamedGraph ;
      sd:name <$BASEURI/$version> .
}
where {}
"
  sparql_update "$statement"
}

# create and load a delta and add metadata for it
load_delta () {

  # parameter check
  if [ -z "$2" ]; then
    echo "function must be called with \$old and \$new parameter"
  else
    old=$1
    new=$2
  fi

  delta_uri=$BASEURI/$old/delta/$new
  printf "\nCreating and loading $delta_uri\n"

  # add triples to version history graph
  statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$old> :hasDelta <$delta_uri> .
  <${BASEURI}record/$new> :hasDelta <$delta_uri> .
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

    # compute the difference between the versions
    # and insert into the delta graph
    if [ $op == 'deletions' ]; then
      minuend=$old
      subtrahend=$new
    else
      minuend=$new
      subtrahend=$old
    fi
    statement="
$PREFIXES
with <$delta_uri/$op>
insert {
  ?s ?p ?o
}
where {
  graph <$BASEURI/$minuend> {
    ?s ?p ?o
  }
  minus {
    graph <$BASEURI/$subtrahend> {
      ?s ?p ?o
    }
  }
  # filter out blank nodes
  filter isIRI(?s)
  filter (isIRI(?o) || isLiteral(?o) || isNumeric(?o))
}
"
    sparql_update "$statement"

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
  <$SERVICE_DDURI> sd:namedGraph <$delta_uri/$op/ng> .
  <$delta_uri/$op/ng> a sd:NamedGraph ;
      sd:name <$delta_uri/$op> .
}
where {}
"
    sparql_update "$statement"

  done
}

##############
# script body
##############

# handle trailing slash in scheme uri
if [ "${SCHEMEURI: -1}" == "/" ]; then
  BASEURI=${SCHEMEURI}version
else
  BASEURI=$SCHEMEURI/version
fi
SPARQL_DDURI=$BASEURI/sparq-service/dd

PREFIXES="
prefix : <http://purl.org/skos-history/>
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
SERVICE_URI=$BASEURI/sparql-service
SERVICE_DDURI=$SERVICE_URI/dd
statement="
$PREFIXES
insert {
<$SERVICE_URI> a sd:Service;
    sd:endpoint <$QUERY_URI>;
    sd:defaultDataset <$SERVICE_DDURI> .
<$SERVICE_DDURI> a sd:Dataset;
    dcterms:title \"$DATASET Versions SPARQL Service\";
    sd:defaultGraph [
        a sd:Graph;
        dcterms:title \"$DATASET Versions SPARQL Service Description\";
    ] .
}
where {}
"
sparql_update "$statement"

# load latest version to the version history graph
latest=${VERSIONS[${#VERSIONS[@]} - 1]}
echo Creating version history
statement="
$PREFIXES
insert {
  # Strangely, WITH syntax does not work here!!
  graph <$BASEURI> {
    <$BASEURI> a dsv:VersionHistorySet ;
        :isVersionHistoryOf <$SCHEMEURI> ;
        dsv:currentVersionRecord <${BASEURI}record/$latest> ;
        void:sparqlEndpoint <$QUERY_URI> ;
        :usingNamedGraph <$BASEURI/ng> .
    <$BASEURI/ng> a sd:NamedGraph ;
        sd:name <$BASEURI> .
    }
}
where {}
"
sparql_update "$statement"

# complement service description
statement="
$PREFIXES
insert {
  <$SERVICE_DDURI> sd:namedGraph <$BASEURI/ng> .
  <$BASEURI/ng> a sd:NamedGraph ;
      sd:name <$BASEURI> .
}
where {}
"
sparql_update "$statement"

# iterate over the versions, load them and add metadata to the version graph
for index in ${!VERSIONS[*]}
do
  version=${VERSIONS[$index]}
  load_version $version
done

# iterate over the versions, create and load deltas + metadata
# (in a second pass, to avoid triples being overridden by version loading)
for index in ${!VERSIONS[*]}
do
  old=${VERSIONS[$index]}
  new=${VERSIONS[$index+1]}
  latest=${VERSIONS[${#VERSIONS[@]} - 1]}
  penultimate=${VERSIONS[${#VERSIONS[@]} - 2]}

  # load delta to the next version
  if [ "$old" != "$latest" ]; then
    load_delta $old $new

    # load a xhv:prev statement for immediately following versions
    statement="
$PREFIXES
with <$BASEURI>
insert {
  <${BASEURI}record/$new> xhv:prev <${BASEURI}record/$old> .
}
where {}
"
    sparql_update "$statement"
  fi

  # load delta to the latest version
  if [ "$old" != "$penultimate" ] && [ "$old" != "$latest" ]; then
    load_delta $old $latest
  fi
done
