#!/usr/bin/perl
# nbt, 6.11.2014

# Creates a csv table of change statistics
# for a set of skos file versions via sparql queries

# Each query must return a result variable "?version" with
# the version indentifier, plus at least one other column with
# the aggregated values for each version

# Query parsing is based on whitespace recognition, minimal:
#   values ( ... ) { ( ... ) }

use strict;
use warnings;
use lib qw(lib);

use Class::CSV;
use Data::Dumper;
use File::Slurp;
use RDF::Query::Client;
use String::Util qw/unquote/;
use URI::file;

my $dataset = $ARGV[0] || 'stw';
my $endpoint = "http://zbw.eu/beta/sparql/${dataset}v/query";

# List of version and data structure for results

# List of queries and parameters for each statistics column

my %definition = (
  'stw' => {
    version_history_set => '<http://zbw.eu/stw/version>',
    versions            => [qw/ 8.04 8.06 8.08 8.10 8.12 8.14 /],
    tables              => [
      {
        title              => 'Concept changes',
        column_definitions => [
          {
            column          => 'version_date',
            header          => 'Date',
            query_file      => '../sparql/version_overview.rq',
            result_variable => 'date',
          },
          {
            column          => 'total_thsys',
            header          => 'Total thsys',
            query_file      => '../sparql/stw/count_concepts.rq',
            replace         => { '?type' => '"Thsys"', },
            result_variable => 'conceptCount',
          },
          {
            column          => 'total_descriptors',
            header          => 'Total descriptors',
            query_file      => '../sparql/stw/count_concepts.rq',
            replace         => { '?type' => '"Descriptor"', },
            result_variable => 'conceptCount',
          },
          {
            column          => 'added_thsys',
            header          => 'Added thsys',
            query_file      => '../sparql/stw/count_added_concepts.rq',
            replace         => { '?conceptType' => 'zbwext:Thsys', },
            result_variable => 'addedConceptCount',
          },
          {
            column          => 'deprecated_concepts',
            header          => 'Deprecated concepts',
            query_file      => '../sparql/count_deprecated_concepts.rq',
            result_variable => 'deprecatedConceptCount',
          },
          {
            column          => 'deleted_concepts',
            header          => 'Deleted concepts',
            query_file      => '../sparql/count_deleted_concepts.rq',
            result_variable => 'deletedConceptCount',
          },
          {
            column          => 'added_descriptors',
            header          => 'Added descriptors',
            query_file      => '../sparql/stw/count_added_concepts.rq',
            replace         => { '?conceptType' => 'zbwext:Descriptor', },
            result_variable => 'addedConceptCount',
          },
          {
            column          => 'deprecated_descriptors',
            header          => 'Deprecated descriptors',
            query_file      => '../sparql/stw/count_deprecated_descriptors.rq',
            replace         => { '?conceptType' => 'zbwext:Descriptor', },
            result_variable => 'deprecatedConceptCount',
          },
          {
            column          => 'deprecated_descriptors_replaced',
            header          => 'Redirected descriptors',
            query_file      => '../sparql/stw/count_deprecated_descriptors.rq',
            replace         => { '?conceptType' => 'zbwext:Descriptor', },
            result_variable => 'replacedByConceptCount',
          },
        ],
      },
      {
        title              => 'Label changes',
        column_definitions => [
          {
            column          => 'added_labels',
            header          => 'Added labels (total en)',
            query_file      => '../sparql/count_added_labels.rq',
            result_variable => 'addedLabelCount',
          },
          {
            column          => 'deleted_labels',
            header          => 'Deleted labels (total en)',
            query_file      => '../sparql/count_deleted_labels.rq',
            result_variable => 'deletedLabelCount',
          },
          {
            column     => 'added_des_labels_en',
            header     => 'Added descriptor labels (en)',
            query_file => '../sparql/stw/count_added_labels.rq',
            replace =>
              { '?language' => '"en"', '?conceptType' => 'zbwext:Descriptor', },
            result_variable => 'addedLabelCount',
          },
          {
            column     => 'deleted_des_labels_en',
            header     => 'Deleted descriptor labels (en)',
            query_file => '../sparql/stw/count_deleted_labels.rq',
            replace    => { '?language' => '"en"', '?type' => '"Descriptor"', },
            result_variable => 'deletedLabelCount',
          },
          {
            column     => 'added_des_labels_de',
            header     => 'Added descriptor labels (de)',
            query_file => '../sparql/stw/count_added_labels.rq',
            replace =>
              { '?language' => '"de"', '?conceptType' => 'zbwext:Descriptor', },
            result_variable => 'addedLabelCount',
          },
          {
            column     => 'deleted_des_labels_de',
            header     => 'Deleted descriptor labels (de)',
            query_file => '../sparql/stw/count_deleted_labels.rq',
            replace    => { '?language' => '"de"', '?type' => '"Descriptor"', },
            result_variable => 'deletedLabelCount',
          },
          {
            column     => 'added_sys_labels_en',
            header     => 'Added thsys labels (en)',
            query_file => '../sparql/stw/count_added_labels.rq',
            replace =>
              { '?language' => '"en"', '?conceptType' => 'zbwext:Thsys', },
            result_variable => 'addedLabelCount',
          },
          {
            column          => 'deleted_sys_labels_en',
            header          => 'Deleted thsys labels (en)',
            query_file      => '../sparql/stw/count_deleted_labels.rq',
            replace         => { '?language' => '"en"', '?type' => '"Thsys"', },
            result_variable => 'deletedLabelCount',
          },
          {
            column     => 'added_sys_labels_de',
            header     => 'Added thsys labels (de)',
            query_file => '../sparql/stw/count_added_labels.rq',
            replace =>
              { '?language' => '"de"', '?conceptType' => 'zbwext:Thsys', },
            result_variable => 'addedLabelCount',
          },
          {
            column          => 'deleted_sys_labels_de',
            header          => 'Deleted thsys labels (de)',
            query_file      => '../sparql/stw/count_deleted_labels.rq',
            replace         => { '?language' => '"de"', '?type' => '"Thsys"', },
            result_variable => 'deletedLabelCount',
          },
        ],
      },
    ],
  },
  'thesoz' => {
    version_history_set => '<http://lod.gesis.org/thesoz/version>',
    versions            => [qw/ 0.7 0.86 0.91 0.92 0.93 /],
    tables              => [
      {
        title              => 'Concept changes',
        column_definitions => [
          {
            column          => 'version_date',
            header          => 'Date',
            query_file      => '../sparql/version_overview.rq',
            result_variable => 'date',
          },
          {
            column          => 'added_concepts',
            header          => 'Added concepts',
            query_file      => '../sparql/count_added_concepts.rq',
            result_variable => 'addedConceptCount',
          },
          {
            column          => 'added_descriptors',
            header          => 'Added descriptors',
            query_file      => '../sparql/stw/count_added_concepts.rq',
            replace         => { '?conceptType' => '<http://lod.gesis.org/thesoz/ext/Descriptor>', },
            result_variable => 'addedConceptCount',
          },
          {
            column          => 'deleted_concepts',
            header          => 'Deleted concepts',
            query_file      => '../sparql/count_deleted_concepts.rq',
            result_variable => 'deletedConceptCount',
          },
        ],
      },
    ],
  },
);

foreach my $table_ref ( @{ $definition{$dataset}{tables} } ) {
  my @column_definitions = @{ $$table_ref{column_definitions} };
  my %data =
    map { $_ => { version => "v $_" } } @{ $definition{$dataset}{versions} };

  # Initialize csv table

  # for each query, get column data and add to csv table

  foreach my $columndef_ref (@column_definitions) {
    print "  $$columndef_ref{column}\n";
    get_column( $columndef_ref, \%data );
  }

  # initialize csv table with column names and headers
  my @columns        = ('version');
  my @column_headers = ('Version');
  foreach my $column_ref (@column_definitions) {
    push( @columns,        $$column_ref{column} );
    push( @column_headers, $$column_ref{header} );
  }
  my $csv = Class::CSV->new( fields => \@columns );
  $csv->add_line( \@column_headers );

  # add rows
  foreach my $row ( @{ $definition{$dataset}{versions} } ) {
    $csv->add_line( $data{$row} );
  }

  # output resulting table
  print "\n", $$table_ref{title}, "\n\n";
  $csv->print;
  print "\n";

}

#######################

sub get_column {
  my $columndef_ref = shift or die "param missing\n";
  my $data_ref      = shift or die "param missing\n";

  # read query from file (by command line argument)
  my $query = read_file( $$columndef_ref{query_file} ) or die "Can't read $!\n";

  # add standard replacement for ?versionHistorySet
  $$columndef_ref{replace}{'?versionHistoryGraph'} =
    $definition{$dataset}{version_history_set};

  # parse VALUES clause
  my ( $variables_ref, $value_ref ) = parse_values($query);

  # replace values
  foreach my $variable ( keys %$value_ref ) {
    if ( defined( $$columndef_ref{replace}{$variable} ) ) {
      $$value_ref{$variable} = $$columndef_ref{replace}{$variable};
    }
  }
  $query = insert_modified_values( $query, $variables_ref, $value_ref );

  # execute query
  my $q        = RDF::Query::Client->new($query);
  my $iterator = $q->execute($endpoint)
    or die "Can't execute $$columndef_ref{query_file}\n";

  # parse and add results
  while ( my $row = $iterator->next ) {
    my $version = unquote( $row->{version}->as_string );
    if ( defined $$data_ref{$version} ) {
      die 'Result variable ', $$columndef_ref{result_variable},
        ' is not defined in ', $$columndef_ref{query_file}, "\n"
        unless $row->{ $$columndef_ref{result_variable} };
      $$data_ref{$version}{ $$columndef_ref{column} } =
        unquote( $row->{ $$columndef_ref{result_variable} }->as_string );
    }
  }
}

sub parse_values {
  my $query = shift or die "param missing\n";

  $query =~ m/ values \s+\(\s+ (.*?) \s+\)\s+\{ \s+\(\s+ (.*?) \s+\)\s+\} /ixms;

  my @variables  = split( /\s+/, $1 );
  my @values_tmp = split( /\s+/, $2 );
  my %value;
  for ( my $i = 0 ; $i < scalar(@variables) ; $i++ ) {
    $value{ $variables[$i] } = $values_tmp[$i];
  }
  return \@variables, \%value;
}

sub insert_modified_values {
  my $query         = shift or die "param missing\n";
  my $variables_ref = shift or die "param missing\n";
  my $value_ref     = shift or die "param missing\n";

  # create new values clause
  my @values;
  foreach my $variable (@$variables_ref) {
    push( @values, $$value_ref{$variable} );
  }
  my $values_clause =
      ' values ( '
    . join( ' ', @$variables_ref )
    . " ) {\n    ( "
    . join( ' ', @values )
    . " )\n  }";

  # insert into query
  $query =~ s/\svalues .*? \s+\)\s+\}/$values_clause/ixms;

  return $query;
}