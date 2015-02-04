#!/bin/sh
# nbt, 1.9.2013

# load a series of version and delta graphs into a SPARQL 1.1 RDF dataset


# Requirements:

# Redland's rapper and rdf.sh`s rdf command should be in $PATH

# START CONFIGURATION

DATASET=$1
VALID_DATASETS=(stw thesoz)

if [ -z "$DATASET" ]; then
  echo "No dataset supplied (valid: ${VALID_DATASETS[*]})"
  exit
elif [[ ! ${VALID_DATASETS[*]} =~ $DATASET ]]; then
  echo "Wrong dataset $DATASET spezified (valid: ${VALID_DATASETS[*]})"
  exit
fi

if [ $DATASET == "stw" ]; then

  # is used to store the SKOS files locally
  #BASEDIR=/opt/thes/var/stw
  BASEDIR=/tmp/stw_versions
  FILENAME=rdf/stw.nt

  # publicly available STW versions
  VERSIONS=(8.04 8.06 8.08 8.10 8.12 8.14)
  ##VERSIONS=(8.08 8.10 8.12)
  SCHEMEURI='http://zbw.eu/stw'

elif [ $DATASET == "thesoz" ]; then

  # thesoz versions must be present locally
  BASEDIR=/opt/thes/var/thesoz
  FILENAME=rdf/thesoz.nt

  # publicly available TheSoz versions
  VERSIONS=(0.7 0.86 0.91 0.92 0.93)
  SCHEMEURI='http://lod.gesis.org/thesoz/'

fi

# implementation-specific uris
#IMPL='sesame'
IMPL='fuseki'
if [ $IMPL == "sesame" ]; then
  ENDPOINT=http://localhost:8080/openrdf-sesame/repositories/${DATASET}v
  PUT_URI=$ENDPOINT/rdf-graphs/service
  UPDATE_URI=$ENDPOINT/statements
  QUERY_URI=$ENDPOINT
elif [ $IMPL == "fuseki" ]; then
  ENDPOINT=http://localhost:3030/${DATASET}v
  PUT_URI=$ENDPOINT/data
  UPDATE_URI=$ENDPOINT/update
  QUERY_URI=http://zbw.eu/beta/sparql/${DATASET}v/query
else
  echo implementation $IMPL not defined
  exit
fi

# END CONFIGURATION

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
      dc:date ?fixeddate;
      dc:identifier ?identifier .
  <$BASEURI/$version/ng> a sd:NamedGraph ;
      sd:name <$BASEURI/$version> .
}
where {
  GRAPH <$BASEURI/$version> {
    # stw and recent thesoz version property
    OPTIONAL { <$SCHEMEURI> owl:versionInfo ?identifier } .
    # old thesoz version prpoperty
    OPTIONAL { <$SCHEMEURI> dcterms:hasVersion ?identifier } .
    # stw uses dcterms:issued
    OPTIONAL { <$SCHEMEURI> dcterms:issued ?date }
    # thesoz uses dcterms:modified (plus dcterms:issued for created date)
    OPTIONAL { <$SCHEMEURI> dcterms:modified ?modified }
    BIND(coalesce(strdt(?modified, xsd:date), strdt(?date, xsd:date), ?date) as ?fixeddate)
  }
}
"
  sparql_update "$statement"

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

  filebase=$BASEDIR/${old}_${new}
  diff=$filebase.diff

  # create the diff
  # (rdf diff converts to sorted n-triples and by default uses /usr/bin/diff)
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
  <$SERVICE_DDURI> sd:namedGraph <$delta_uri/$op/ng> .
  <$delta_uri/$op/ng> a sd:NamedGraph ;
      sd:name <$delta_uri/$op> .
}
where {}
"
    sparql_update "$statement"

  done

  # cleanup
  /bin/rm $filebase*
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
