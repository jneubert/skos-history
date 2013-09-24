#!/bin/sh
# nbt, 1.9.2013

# load a series of graphs and deltas into a fuseki dataset


# Requirements:

# FUSEKI_HOME should already be defined.

# If the installed system-wide ruby version is < 1.8.7 (e.g., on CentOS 5),
# Fuseki utilities will refuse to work. A more current ruby version may be
# installed somewhere and put at the beginning of $PATH. The Ruby section of
# http://www.geekytidbits.com/ruby-on-rails-in-centos-5/ worked for me.

# Redland's rapper and rdf.sh`s rdf command should be in $PATH


# START CONFIGURATION

# is used to store the SKOS files locally
#BASEDIR=/opt/thes/var/stw
BASEDIR=/tmp/stw_versions
ENDPOINT=http://localhost:3030/stwv

# END CONFIGURATION


# publicly available STW versions
VERSIONS=(8.04 8.06 8.08 8.10)
BASEURI=http://zbw.eu/stw/version
PREFIXES="
prefix : <http://raw.github.com/jneubert/skos-history/master/skos-history.ttl/>
prefix dc: <http://purl.org/dc/elements/1.1/>
prefix dcterms: <http://purl.org/dc/terms/>
prefix owl: <http://www.w3.org/2002/07/owl#>
prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#>
prefix skos: <http://www.w3.org/2004/02/skos/core#>
prefix xsd: <http://www.w3.org/2001/XMLSchema#>
"

# getting the data from http://zbw.eu/stw, if it does not exist locally
for index in ${!VERSIONS[*]}
do
  version=${VERSIONS[$index]}
  dir=$BASEDIR/$version/rdf
  file=$dir/stw.nt
  if [ ! -f $file ]; then
    mkdir -p $dir
    download_url="http://zbw.eu/stw/versions/$version/download/stw.rdf.zip"
    echo "downloading $download_url"
    download_file="$dir/stw.rdf.zip"
    wget -O $download_file $download_url
    unzip -d $dir $download_file
    rapper -i guess $dir/stw.rdf > $file
    rm $download_file $dir/stw.rdf
  fi
done

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
  <$BASEURI/$old> dcterms:isVersionOf <http://zbw.eu/stw> .
}
where {}
"
  $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

  # add triples to the default graph
  statement="
$PREFIXES
insert {
  <$BASEURI/$old> a :SchemeVersion .
  <http://zbw.eu/stw> dcterms:hasVersion <$BASEURI/$old>
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
  <http://zbw.eu/stw> :hasDelta <$delta_uri> .
  <$delta_uri> :deltaFrom <$BASEURI/$old> .
  <$delta_uri> :deltaTo <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
    # add triples to old version graph
    statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$BASEURI/$old> :hasDelta <$delta_uri> .
  <$delta_uri> :deltaFrom <$BASEURI/$old> .
  <$delta_uri> :deltaTo <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
    # add triples to old version graph
    statement="
$PREFIXES
with <$BASEURI/$new>
insert {
  <$BASEURI/$new> :hasDelta <$delta_uri> .
  <$delta_uri> a :SchemeDelta .
  <$delta_uri> :deltaFrom <$BASEURI/$old> .
  <$delta_uri> :deltaTo <$BASEURI/$new> .
}
where {}
"
    $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

    # load delta
    for op in deletions insertions; do

      # make variable with first character uppercased
      op_var="$(tr '[:lower:]' '[:upper:]' <<< ${op:0:1})${op:1}"

      # load file
      $FUSEKI_HOME/s-put $ENDPOINT/data $delta_uri/$op ${filebase}_$op.nt

      echo add triples to the delta graph for $op
      statement="
$PREFIXES
with <$delta_uri/$op>
insert {
  <$delta_uri/$op> a :SchemeDelta$op_var .
  <$delta_uri/$op> dcterms:isPartOf <$delta_uri> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
      echo add triples to both version graphs for $op
      statement="
$PREFIXES
with <$BASEURI/$old>
insert {
  <$delta_uri/$op> a :SchemeDelta$op_var .
  <$delta_uri> dcterms:hasPart <$delta_uri/$op> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"
      statement="
$PREFIXES
with <$BASEURI/$new>
insert {
  <$delta_uri/$op> a :SchemeDelta$op_var .
  <$delta_uri> dcterms:hasPart <$delta_uri/$op> .
}
where {}
"
      $FUSEKI_HOME/s-update --service $ENDPOINT/update "$statement"

    done
  fi
done
