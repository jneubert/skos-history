#!/usr/bin/perl
# nbt, 6.11.2014

# Creates a csv table of change statistics

# Each query must return a result variable with the name given
# in row_head_name (e.g. 'version', or 'category'), plus at least one
# other column with the aggregated values for each row_head.

# Query parsing is based on whitespace recognition, minimal:
#   values ( ... ) { ( ... ) }

use strict;
use warnings;
use lib qw(lib);
use utf8;

use Class::CSV;
use Data::Dumper;
use File::Slurp;
use HTML::Template;
use JSON -support_by_pp;
use RDF::Query::Client;
use String::Util qw/unquote/;
use URI::file;

# create utf8 output
binmode( STDOUT, ":utf8" );

my $output_dir = '/var/www/html/beta/tmp2';

# List of version and data structure for results

# subthes collation sequence
my @subthes_sequence = qw/ B V W P N G A /;

my %definition = %{ get_definition() };

my $dataset = $ARGV[0];
my $table   = $ARGV[1];

if ( not( $dataset and $definition{$dataset} ) ) {
  print_usage();
  exit;
}

my $endpoint = "http://zbw.eu/beta/sparql/${dataset}v/query";

# Main loop over all tables of a dataset
my %csv_data;
foreach my $table_ref ( @{ $definition{$dataset}{tables} } ) {

  # TODO remove next line
  next if ref( $$table_ref{title} ) eq '';

  # If a table parameter is given, skip everything else
  if ( $table and $$table_ref{name} ne $table ) {
    next;
  }
  print "\n$$table_ref{name}\n";
  my @column_definitions = @{ $$table_ref{column_definitions} };
  my ( @row_heads, %data );

  # for each column (query), get column data
  foreach my $columndef_ref (@column_definitions) {
    print "  $$columndef_ref{column}\n";
    get_column( $$table_ref{row_head_name},
      $columndef_ref, \@row_heads, \%data );
  }

  foreach my $lang ( @{ $$table_ref{languages} } ) {

    # create the csv data structue
    my $csv = build_csv( $lang, \@column_definitions, \@row_heads, \%data );

    # create custom order of sub-thesauri
    if ( $$table_ref{row_head_name} eq 'topConcept' ) {
      $csv = collate_subthes($csv);
    }
    $csv_data{ $$table_ref{name} } = $csv;

    # output for csv
    print_csv( $lang, $table_ref, $csv );

    # output for charts
    if ( exists( $$table_ref{chart_data} ) ) {
      print_charts( $lang, $csv, $table_ref );
    }
  }
}

#######################

sub print_usage {
  print "\nUsage: $0 dataset [table]\n";
  print "\nAvailable datasets and tables:\n";
  foreach my $dataset ( sort keys %definition ) {
    print "  $dataset\n";
    foreach my $table_ref ( @{ $definition{$dataset}{tables} } ) {

      # TODO remove next line
      next if ref( $$table_ref{title} ) eq '';
      my $charts = join( ', ', sort keys %{ $$table_ref{chart_data} } );
      print "    $$table_ref{name} (Charts: $charts)\n";
    }
  }
  print "\n";
}

sub get_column {
  my $row_head_name = shift or die "param missing\n";
  my $columndef_ref = shift or die "param missing\n";
  my $row_head_ref  = shift or die "param missing\n";
  my $data_ref      = shift or die "param missing\n";

  # when $data_ref is empty, treat column differently
  my $first_column = %{$data_ref} ? undef : 1;

  # read query from file (by command line argument)
  my $query = read_file( $$columndef_ref{query_file} )
    or die "Can't read $!\n";

  # add standard replacement for ?versionHistorySet
  $$columndef_ref{replace}{'?versionHistoryGraph'} =
    $definition{$dataset}{version_history_set};

  # column must get a sub-stucture by language if multilingual
  my $multi_lingual = 0;
  my @languages     = ('en');
  if ( exists( $$columndef_ref{languages} ) ) {
    $multi_lingual = 1;
    @languages     = @{ $$columndef_ref{languages} };
  }

  foreach my $lang (@languages) {

    # add standard replacement for ?versionHistorySet
    $$columndef_ref{replace}{'?language'} = "\"$lang\"";

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
      my $row_head = unquote( $row->{$row_head_name}->as_string );

      if ( defined $$data_ref{$row_head} or $first_column ) {
        die 'Result variable ', $$columndef_ref{result_variable},
          ' is not defined in ', $$columndef_ref{query_file}, "\n"
          unless $row->{ $$columndef_ref{result_variable} };

        my $value =
          unquote( $row->{ $$columndef_ref{result_variable} }->as_string );
        if ($multi_lingual) {
          $$data_ref{$row_head}{ $$columndef_ref{column} }{$lang} = $value;
        } else {
          $$data_ref{$row_head}{ $$columndef_ref{column} } = $value;
        }

        # the list of row headings is dynamically created here
        if ($first_column) {
          push( @{$row_head_ref}, $row_head );
        }
      }
    }

    # first columns actions must only be executed once, with the first language
    $first_column = 0;
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

sub build_csv {
  my $lang               = shift        or die "param missing\n";
  my @column_definitions = @{ shift() } or die "param missing\n";
  my @row_heads          = @{ shift() } or die "param missing\n";
  my $data_ref           = shift        or die "param missing\n";

  # initialize csv table with column names and headers
  my ( @columns, @column_headers );
  foreach my $column_ref (@column_definitions) {
    push( @columns,        $$column_ref{column} );
    push( @column_headers, $$column_ref{header}{$lang} );
  }
  my $csv = Class::CSV->new( fields => \@columns );
  $csv->add_line( \@column_headers );

  # add rows
  foreach my $row_head (@row_heads) {

    # map multilingual columns to a flat data structure
    my %row = %{ $$data_ref{$row_head} };
    foreach my $column_ref (@column_definitions) {
      if ( exists( $$column_ref{languages} ) ) {
        $row{ $$column_ref{column} } = $row{ $$column_ref{column} }{$lang};
      }
    }
    $csv->add_line( \%row );
  }
  return $csv;
}

sub collate_subthes {
  my $csv = shift or die "param missing\n";

  # parse all csv lines into a hash keyed by subthes
  # and prepared for adding
  my %line;
  foreach my $line ( @{ $csv->lines() } ) {
    my $subthes = substr( $line->get('topConcept'), 0, 1 );
    my $fields_ref;
    foreach my $field ( @{ $csv->fields() } ) {
      push( @{$fields_ref}, $line->get($field) );
    }
    $line{$subthes} = $fields_ref;
  }

  # initialize a new csv object
  my $csv2 = Class::CSV->new( fields => $csv->fields() );
  $csv2->add_line( $csv->fields );

  # add lines according to collation sequence
  for my $subthes (@subthes_sequence) {
    $csv2->add_line( $line{$subthes} );
  }

  return $csv2;
}

sub print_csv {
  my $lang      = shift or die "param missing\n";
  my $table_ref = shift or die "param missing\n";
  my $csv       = shift or die "param missing\n";

  # output resulting table
  my $fn = "$output_dir/$$table_ref{name}.$lang.csv";
  write_file( $fn, { binmode => ':utf8' }, $csv->string );

  print "  CSV: $$table_ref{title}{$lang}\n";
}

# Prints data formatted for insertion into a
# highcharts.com bar-negative-stack chart
sub print_charts {
  my $lang      = shift or die "param missing\n";
  my $csv       = shift or die "param missing\n";
  my $table_ref = shift or die "param missing\n";

  my @charts_with_drilldown = ();

  my %chart_data = %{ $$table_ref{chart_data} };
  foreach my $chart ( keys %chart_data ) {

    # create a data structure which can directly been mapped to json

    # get columns referenced for the chart
    my $column1_ref =
      $$table_ref{column_definitions}[ $chart_data{$chart}{columns}[0] ];
    my $column2_ref =
      $$table_ref{column_definitions}[ $chart_data{$chart}{columns}[1] ];

    # all but the first line, which contains column headers
    my @lines = @{ $csv->lines }[ 1 .. $#{ $csv->lines } ];

    my ( @series, @all_values );

    # set negative value for the first column
    my $set_negative = 1;
    foreach my $column_ref ( $column1_ref, $column2_ref ) {
      my %column;
      $column{name} = $$column_ref{header}{$lang};
      my @data;
      foreach my $line (@lines) {
        my %cell;
        $cell{name} = $line->get( $$table_ref{row_head_name} );
        my $value = $line->get( $$column_ref{column} ) || 0;
        push( @all_values, $value );

        # explicitly cast to number, otherwise json generates a string
        $cell{y} = $set_negative ? -$value : abs($value);
        push( @data, \%cell );
      }
      $column{data} = \@data;
      push( @series, \%column );
      $set_negative = 0;
    }

    # set flags to control drilldowns links
    my $dd_chart =
      grep( /$$table_ref{name}/, qw/ concepts_by_subthes / )
      ? 1
      : 0;
    my $dd_report =
          grep( /$$table_ref{name}/, qw/ concepts_by_category / )
      and grep( /$chart/, qw/ changed_descriptors changed_thsys / )
      ? 1
      : 0;
    my $drilldown =
      $dd_chart or $dd_report
      ? 1
      : 0;

    # create js file
    my %tmpl_var = (
      title      => $chart_data{$chart}{title}{$lang},
      subtitle   => 'Version 8.06 to 8.14',
      is_diff    => $chart_data{$chart}{type} eq 'diffs',
      grid_width => get_max(@all_values) + 1,
      height     => get_height($csv),
      series     => to_json( \@series, { pretty => 1 } ),
      drilldown  => $drilldown,
      dd_chart   => $dd_chart,
      dd_report  => $dd_report,
      url_part   => "$chart.$lang.html",
    );
    my $tmpl = HTML::Template->new( filename => 'tmpl/stw_delta.js.tmpl', );
    $tmpl->param( \%tmpl_var );
    my $fn = "$output_dir/$chart.$lang.js";
    write_file( $fn, { binmode => ':utf8' }, $tmpl->output() );

    # creae html file
    %tmpl_var = (
      lang     => $lang,
      chart_js => "$chart.$lang.js",
    );
    $tmpl = HTML::Template->new( filename => 'tmpl/stw_delta.html.tmpl', );
    $tmpl->param( \%tmpl_var );
    $fn = "$output_dir/$chart.$lang.html";
    write_file( $fn, { binmode => ':utf8' }, $tmpl->output() );

    print "  Chart: $chart_data{$chart}{title}{$lang}\n";
  }
}

sub get_max {
  my @vars = @_;

  my $max = 0;
  for (@vars) {
    $max = $_ if $_ > $max;
  }
  return $max;
}

sub get_height {
  my $csv = shift or die "param missing\n";

  my $line_height = 40;

  my $no_of_lines = scalar( @{ $csv->lines() } );

  return $line_height * $no_of_lines;
}

sub get_definition {

  # List of queries and parameters for each statistics column
  # (the first column for each table must return the row_head values).

  my %definition = (
    'stw' => {
      version_history_set => '<http://zbw.eu/stw/version>',
      tables              => [
        {
          title => {
            en => 'Concept changes (by version)',
            de => 'Begriffsänderungen (nach Version)',
          },
          name               => 'concepts_by_version',
          languages          => [qw/ en de /],
          row_head_name      => 'version',
          column_definitions => [
            {
              column => 'version',
              header => {
                en => 'Version',
                de => 'Version',
              },
              query_file      => '../sparql/version_overview.rq',
              result_variable => 'version',
            },
            {
              column => 'version_date',
              header => {
                en => 'Date',
                de => 'Datum',
              },
              query_file      => '../sparql/version_overview.rq',
              result_variable => 'date',
            },
            {
              column => 'total_thsys',
              header => {
                en => 'Total categories',
                de => 'Gesamtzahl Systematikstellen',
              },
              query_file      => '../sparql/stw/count_concepts.rq',
              replace         => { '?type' => '"Thsys"', },
              result_variable => 'conceptCount',
            },
            {
              column => 'total_descriptors',
              header => {
                en => 'Total descriptors',
                de => 'Gesamtzahl Deskriptoren',
              },
              query_file      => '../sparql/stw/count_concepts.rq',
              replace         => { '?type' => '"Descriptor"', },
              result_variable => 'conceptCount',
            },
            {
              column => 'added_thsys',
              header => {
                en => 'Added categories',
                de => 'Zugefügte Systematikstellen',
              },
              query_file      => '../sparql/stw/count_added_concepts.rq',
              replace         => { '?conceptType' => 'zbwext:Thsys', },
              result_variable => 'addedConceptCount',
            },
            {
              column => 'added_descriptors',
              header => {
                en => 'Added descriptors',
                de => 'Zugefügte Deskriptoren',
              },
              query_file      => '../sparql/stw/count_added_concepts.rq',
              replace         => { '?conceptType' => 'zbwext:Descriptor', },
              result_variable => 'addedConceptCount',
            },
            {
              column => 'deprecated_descriptors',
              header => {
                en => 'Deprecated descriptors',
                de => 'Stillgelegte Deskriptoren',
              },
              query_file      => '../sparql/stw/count_deprecated_concepts.rq',
              replace         => { '?conceptType' => 'zbwext:Descriptor', },
              result_variable => 'deprecatedConceptCount',
            },
            {
              column => 'deprecated_descriptors_replaced',
              header => {
                en => 'Redirected',
                de => 'Verweise',
              },
              query_file      => '../sparql/stw/count_deprecated_concepts.rq',
              replace         => { '?conceptType' => 'zbwext:Descriptor', },
              result_variable => 'replacedByConceptCount',
            },
          ],
        },
        {
          title              => 'Label changes by version',
          name               => 'labels_by_version',
          row_head_name      => 'version',
          column_definitions => [
            {
              column          => 'version',
              header          => 'Version',
              query_file      => '../sparql/version_overview.rq',
              result_variable => 'version',
            },
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
              replace    => {
                '?language'    => '"en"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'addedLabelCount',
            },
            {
              column     => 'deleted_des_labels_en',
              header     => 'Deleted descriptor labels (en)',
              query_file => '../sparql/stw/count_deleted_labels.rq',
              replace => { '?language' => '"en"', '?type' => '"Descriptor"', },
              result_variable => 'deletedLabelCount',
            },
            {
              column     => 'added_des_labels_de',
              header     => 'Added descriptor labels (de)',
              query_file => '../sparql/stw/count_added_labels.rq',
              replace    => {
                '?language'    => '"de"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'addedLabelCount',
            },
            {
              column     => 'deleted_des_labels_de',
              header     => 'Deleted descriptor labels (de)',
              query_file => '../sparql/stw/count_deleted_labels.rq',
              replace => { '?language' => '"de"', '?type' => '"Descriptor"', },
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
              column     => 'deleted_sys_labels_en',
              header     => 'Deleted thsys labels (en)',
              query_file => '../sparql/stw/count_deleted_labels.rq',
              replace    => { '?language' => '"en"', '?type' => '"Thsys"', },
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
              column     => 'deleted_sys_labels_de',
              header     => 'Deleted thsys labels (de)',
              query_file => '../sparql/stw/count_deleted_labels.rq',
              replace    => { '?language' => '"de"', '?type' => '"Thsys"', },
              result_variable => 'deletedLabelCount',
            },
          ],
        },
        {
          title => {
            en => 'Concept changes (by 2nd level category)',
            de => 'Begriffsänderungen (nach Grobstematikstelle)',
          },
          name          => 'concepts_by_category',
          row_head_name => 'secondLevelCategory',
          languages     => [qw/ en de /],
          chart_data    => {
            total_descriptors => {
              type  => 'totals',
              title => {
                en => 'Descriptors (by 2nd level category)',
                de => 'Deskriptoren (nach Grobsystematikstelle)',
              },
              columns => [ 1, 2 ],
            },
            changed_descriptors => {
              type  => 'diffs',
              title => {
                en =>
                  'Added and deprecated descriptors (by 2nd level category)',
                de =>
'Neue und stillgelegte Deskriptoren (nach Grobsystematikstelle)',
              },
              columns => [ 4, 3 ],
            },
            changed_thsys => {
              type  => 'diffs',
              title => {
                en =>
                  'Added and deprecated descriptors (by 2nd level category)',
                de =>
'Neue und stillgelegte Deskriptoren (nach Grobsystematikstelle)',
              },
              columns => [ 6, 5 ],
            },
            total_thsys => {
              type  => 'totals',
              title => {
                en => 'Categories (by 2nd level category)',
                de => 'Systematikstellen (nach Grobsystematikstelle)',
              },
              columns => [ 7, 8 ],
            },
          },
          column_definitions => [
            {
              column => 'secondLevelCategory',
              header => {
                en => '2nd level category',
                de => 'Grobsystematikstelle',
              },
              languages  => [qw/ en de /],
              query_file => '../sparql/stw/count_total_concepts_by_category.rq',
              result_variable => 'secondLevelCategoryLabel',
            },
            {
              column => 'total_descriptors_8.06',
              header => {
                en => 'Total descriptors 8.06',
                de => 'Gesamtzahl Deskriptoren 8.06',
              },
              query_file => '../sparql/stw/count_total_concepts_by_category.rq',
              replace    => {
                '?newVersion'  => '"8.06"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'totalConcepts',
            },
            {
              column => 'total_descriptors_8.14',
              header => {
                en => 'Total descriptors 8.14',
                de => 'Gesamtzahl Deskriptoren 8.14',
              },
              query_file => '../sparql/stw/count_total_concepts_by_category.rq',
              replace    => {
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'totalConcepts',
            },
            {
              column => 'added_descriptors',
              header => {
                en => 'Added descriptors',
                de => 'Zugefügte Deskriptoren',
              },
              query_file => '../sparql/stw/count_added_concepts_by_category.rq',
              replace    => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'addedConcepts',
            },
            {
              column => 'deprecated_descriptors',
              header => {
                en => 'Deprecated descriptors',
                de => 'Stillgelegte Deskriptoren',
              },
              query_file =>
                '../sparql/stw/count_deprecated_concepts_by_category.rq',
              replace => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Descriptor',
              },
              result_variable => 'deprecatedConcepts',
            },
            {
              column => 'added_thsys',
              header => {
                en => 'Added categories',
                de => 'Zugefügte Systematikstellen',
              },
              query_file => '../sparql/stw/count_added_concepts_by_category.rq',
              replace    => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'addedConcepts',
            },
            {
              column => 'deprecated_thsys',
              header => {
                en => 'Deprecated categories',
                de => 'Stillgelegte Systematikstellen',
              },
              query_file =>
                '../sparql/stw/count_deprecated_concepts_by_category.rq',
              replace => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'deprecatedConcepts',
            },
            {
              column => 'total_thsys_8.06',
              header => {
                en => 'Total categories 8.06',
                de => 'Gesamtzahl Systematikstellen 8.06',
              },
              query_file => '../sparql/stw/count_total_concepts_by_category.rq',
              replace    => {
                '?newVersion'  => '"8.06"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'totalConcepts',
            },
            {
              column => 'total_thsys_8.14',
              header => {
                en => 'Total categories 8.14',
                de => 'Gesamtzahl Systematikstellen 8.14',
              },
              query_file => '../sparql/stw/count_total_concepts_by_category.rq',
              replace    => {
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'totalConcepts',
            },
          ],
        },
        {
          title => {
            en => 'Concept changes (by sub-thesaurus)',
            de => 'Geänderte Begriffe (nach Subthesaurus)',
          },
          name          => 'concepts_by_subthes',
          row_head_name => 'topConcept',
          languages     => [qw/ en de /],
          chart_data    => {
            total_descriptors => {
              type  => 'totals',
              title => {
                en => 'Descriptors (by sub-thesaurus)',
                de => 'Deskriptoren (nach Subthesaurus)',
              },
              columns => [ 1, 2 ],
            },
            changed_descriptors => {
              type  => 'diffs',
              title => {
                en => 'Added and deprecated descriptors (by sub-thesaurus)',
                de => 'Neue und stillgelegte Deskriptoren (nach Subthesaurus)',
              },
              columns => [ 4, 3 ],
            },
            changed_thsys => {
              type  => 'diffs',
              title => {
                en => 'Added and deprecated descriptors (by sub-thesaurus)',
                de => 'Neue und stillgelegte Deskriptoren (nach Subthesaurus)',
              },
              columns => [ 6, 5 ],
            },
            total_thsys => {
              type  => 'totals',
              title => {
                en => 'Categories (by sub-thesaurus)',
                de => 'Systematikstellen (nach Subthesaurus)',
              },
              columns => [ 7, 8 ],
            },
          },
          column_definitions => [
            {
              column    => 'topConcept',
              languages => [qw/ en de /],
              header    => {
                en => 'Sub-thesaurus',
                de => 'Subthesaurus',
              },
              query_file      => '../sparql/stw/count_total_concepts_by_top.rq',
              result_variable => 'topConceptLabel',
            },
            {
              column => 'total_descriptors_8.06',
              header => {
                en => 'Total descriptors 8.06',
                de => 'Gesamtzahl Deskriptoren 8.06',
              },
              query_file      => '../sparql/stw/count_total_concepts_by_top.rq',
              replace         => { '?newVersion' => '"8.06"', },
              result_variable => 'totalConcepts',
            },
            {
              column => 'total_descriptors_8.14',
              header => {
                en => 'Total descriptors 8.14',
                de => 'Gesamtzahl Deskriptoren 8.14',
              },
              query_file      => '../sparql/stw/count_total_concepts_by_top.rq',
              replace         => { '?newVersion' => '"8.14"', },
              result_variable => 'totalConcepts',
            },
            {
              column => 'added_descriptors',
              header => {
                en => 'Added descriptors',
                de => 'Zugefügte Deskriptoren',
              },
              query_file => '../sparql/stw/count_added_concepts_by_top.rq',
              replace    => {
                '?oldVersion' => '"8.06"',
                '?newVersion' => '"8.14"',
              },
              result_variable => 'addedConcepts',
            },
            {
              column => 'deprecated_descriptors',
              header => {
                en => 'Deprecated descriptors',
                de => 'Stillgelegte Deskriptoren',
              },
              query_file => '../sparql/stw/count_deprecated_concepts_by_top.rq',
              replace    => {
                '?oldVersion' => '"8.06"',
                '?newVersion' => '"8.14"',
              },
              result_variable => 'deprecatedConcepts',
            },
            {
              column => 'added_thsys',
              header => {
                en => 'Added categories',
                de => 'Zugefügte Systematikstellen',
              },
              query_file => '../sparql/stw/count_added_concepts_by_top.rq',
              replace    => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'addedConcepts',
            },
            {
              column => 'deprecated_thsys',
              header => {
                en => 'Deprecated categories',
                de => 'Stillgelegte Systematikstellen',
              },
              query_file => '../sparql/stw/count_deprecated_concepts_by_top.rq',
              replace    => {
                '?oldVersion'  => '"8.06"',
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'deprecatedConcepts',
            },
            {
              column => 'total_thsys_8.06',
              header => {
                en => 'Total categories 8.06',
                de => 'Gesamtzahl Systematikstellen 8.06',
              },
              query_file => '../sparql/stw/count_total_concepts_by_top.rq',
              replace    => {
                '?newVersion'  => '"8.06"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'totalConcepts',
            },
            {
              column => 'total_thsys_8.14',
              header => {
                en => 'Total categories 8.14',
                de => 'Gesamtzahl Systematikstellen 8.14',
              },
              query_file => '../sparql/stw/count_total_concepts_by_top.rq',
              replace    => {
                '?newVersion'  => '"8.14"',
                '?conceptType' => 'zbwext:Thsys',
              },
              result_variable => 'totalConcepts',
            },
          ],
        },
      ],
    },
    'thesoz' => {
      version_history_set => '<http://lod.gesis.org/thesoz/version>',
      tables              => [
        {
          title              => 'Concept changes by version',
          name               => 'concepts_by_version',
          row_head_name      => 'version',
          column_definitions => [
            {
              column          => 'version',
              header          => 'Version',
              query_file      => '../sparql/version_overview.rq',
              result_variable => 'version',
            },
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
              column     => 'added_descriptors',
              header     => 'Added descriptors',
              query_file => '../sparql/stw/count_added_concepts.rq',
              replace    => {
                '?conceptType' =>
                  '<http://lod.gesis.org/thesoz/ext/Descriptor>',
              },
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

  return \%definition;
}
