#!/usr/bin/perl
# nbt, 6.11.2014

# Creates a csv table of change statistics
# for a set of skos file versions via sparql queries

# query parsing is based on whitespace recognition, minimal:
#   values ( ... ) { ( ... ) }

use strict;
use warnings;
use lib qw(lib);

use Data::Dumper;
use File::Slurp;
use File::Spec;
use URI::file;
use RDF::Query;

# List of queries and parameters for each statistics column

my @column_definitions = (
  {
    header     => 'Added labels (en)',
    query_file => '../sparql/count_added_labels.rq',
    replace    => {
      '?language' => '"en"',
    },
  },
  {
    header     => 'Added labels (de)',
    query_file => '../sparql/count_added_labels.rq',
    replace    => {
      '?language' => '"de"',
    },
  },
);

# Initialize csv table

# for each query, get column data and add to csv table

foreach my $column_definition_ref (@column_definitions) {
  my $column_ref = get_column($column_definition_ref);

  # add to csv table
}

# output resulting table

#######################

sub get_column {
  my %columndef = %{ shift() } or die "param missing\n";

  # read query from file (by command line argument)
  my $query = read_file( $columndef{query_file} ) or die "Can't read $!\n";

  # parse VALUES clause
  my ( $variables_ref, $value_ref ) = parse_values($query);

  # replace values
  foreach my $variable ( keys %$value_ref ) {
    if ( defined( $columndef{replace}{$variable} ) ) {
      $$value_ref{$variable} = $columndef{replace}{$variable};
    }
  }
  $query = insert_modified_values( $query, $variables_ref, $value_ref );

  # execute query

  print "$query\n";

  # parse results

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
