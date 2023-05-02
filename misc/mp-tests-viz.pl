#!/usr/bin/perl

my $opts = parse_params();
process_tests($opts);
create_output($opts);
exit;

#--------------------------------

sub error
{
    my (@msg) = @_;
    if ( scalar @msg ) { print @msg,"\n"; }
    print 
        "About: This is a script that creates an asciidoc file with data to visualize results obtained from \"mpileup-tests\"\n",
        "Usage: mp-tests-viz.pl [OPTIONS]\n",
        "Options:\n",
        "   -i, --infile <file>         File with results from mpileup-tests\n",
        "   -l                          Show screenshots as links to github\n",
        "   -o, --outfile <file>        Output file\n",
        "   -h, -?, --help              This help message\n",
        "\n";
    exit -1;
}

sub parse_params
{
    my $opts = { link_pictures=>0 };
    while (defined(my $arg=shift(@ARGV)))
    {
		if ( $arg eq '-i' || $arg eq '--infile' ) { $$opts{infile}=shift(@ARGV); next }
        if ( $arg eq '-o' || $arg eq '--outdir' ) { $$opts{outfile}=shift(@ARGV); next }
        if ( $arg eq '-l' ) { $$opts{link_pictures}=1; next }
        if ( $arg eq '-?' || $arg eq '-h' || $arg eq '--help' ) { error(); }
        error("Unknown parameter \"$arg\". Run -h for help.\n");
    }
	if ( !exists($$opts{infile}) ) { error("Missing the -i, --input-file option.\n"); }
	if ( !exists($$opts{outfile}) ) { error("Missing the -o option.\n"); }
	return $opts;
}

sub process_tests
{
    my ($opts) = @_;

    # File manipulation
    my $dir = "temp";
	if ( !mkdir $dir ) { error("Unable to create temporary directory\n"); }

    open(TESTS, "<$$opts{infile}") or error("Unable to open the input file\n");
    open(HEAD, ">temp/header.adoc") or error("Unable to create a temporary file\n");
    open(DATATABLE, ">temp/table.adoc") or error("Unable to create a temporary file\n");
    open(SNAPSHOTS, ">temp/snaps.adoc") or error("Unable to create a temporary file\n");

    # Print headers
    print HEAD "== Visualisation of results from the file $$opts{infile}\n";
    print HEAD ":imagesdir: https://raw.githubusercontent.com/pd3/mpileup-tests/main/dat\n\n";
    print HEAD "=== Basic statistics\n";
    print DATATABLE "\n=== Results\n";
    print DATATABLE "[cols=\"1,1,1,1\"]\n";
    print DATATABLE "|===\n";
    print DATATABLE "|File |State |Command |Exp/Found\n\n";
    print SNAPSHOTS "\n=== Snapshots\n";
    
    # Define variables
    my $cmd;
    my $error_counter = 0;
    my $file_name;
    my $header = 0;
    my $snapshot_count = 1;
    my $substr;
    my $snapshot_name = "none";
    my @split_line;
    # -1 => default, be prepared to parse
    #  0 => error, test didn't run
    #  1 => something was missed (region / variant / detail)
    #  2 => all ok
    #  3 => reading header
    my $state = -1;


    while (my $line = <TESTS>)
    {
        # Empty line
        if ($line =~ /^\s*$/ && $state <= 2) { 
            $state = -1;
            $snapshot_name = "none";
            next;
        }

        # Unimportant lines (mainly error messages)
        if ($state != -1) { next; }

        # Parse snapshot line
        $substr = "snapshot";
        if (index($line, $substr) != -1) {
            # Parse the snapshot file name
            @split_line = split(/\s+/, $line);
            $snapshot_name = $split_line[$#split_line];
            next;
        }

        # Parse information from a test
        $substr = "bcftools mpileup";
        if (index($line, $substr) != -1) {

            # Parse file name
            @split_line1 = split('\|', $line);
            $cmd = $split_line1[0];
            @split_line2 = split(/\s+/, $split_line1[0]);
            $file_name = $split_line2[-1];

            # Print file name
            if ($snapshot_name eq "none") {
                print DATATABLE "\n|$file_name\n";
            } else {
                if ($$opts{link_pictures} == 0) {
                    print DATATABLE "\n|<<picture$snapshot_count, $file_name>>\n";
                    print SNAPSHOTS "Image of $file_name [[picture$snapshot_count]]\n\n";
                    print SNAPSHOTS "image::$snapshot_name";
                    print SNAPSHOTS "[]\n\n";
                    $snapshot_count++;
                } else {
                    print DATATABLE "\n|image::$file_name\[link=\"$snapshot_name\"\]\n";
                }
            }

            # Print state
            $line = <TESTS>;
            while (index($line, "..") != -1) {
                if (index($line, "ERROR") != -1) {
                    print DATATABLE "|error\n";
                    $state = 0;
                    $error_counter++;
                    last;
                } elsif (index($line, "missed") != -1) {
                    chomp $line;
                    my $string = substr $line, 3;
                    print DATATABLE "|$string\n";
                    $state = 1;
                    last;
                } else {
                    $state = 2;
                    $line = <TESTS>;
                }
            }
            if ($state == 2) { print DATATABLE "|ok\n"; }

            # Print Command 
            print DATATABLE "|$cmd\n";

            # Print Exp/Found
            if ($state == 1) { 
                print DATATABLE "a|\n";
                $line = <TESTS>;
                while ($line =~ /\S/) {
                    chomp $line;
                    my $string = substr $line, 1;
                    print DATATABLE "- $string\n";
                    $line = <TESTS>;
                }
            } else {
                print DATATABLE "|\n"
            }

            # Test for empty line
            if ($line =~ /^\s*$/) { 
                $state = -1;
                $snapshot_name = "none";
            }

        }

        # Parse header
        $substr = "Number of tests";
        if (index($line, $substr) != -1 || $header == 1) { 
            print HEAD ".$line";
            
            $line = <TESTS>;
            @split_line = split(/\s+/, $line);
            print HEAD "* Total: $split_line[2]\n";

            if ($header == 1) {
                $line = <TESTS>;
                @split_line = split(/\s+/, $line);
                print HEAD "* Passed: $split_line[2] $split_line[3]\n";
            }

            $line = <TESTS>;
            @split_line = split(/\s+/, $line);
            if ($header == 0) {
                print HEAD "* Errors: $split_line[2] $split_line[3]\n";
                $header = 1
            } else {
                print HEAD "* Missed: $split_line[2] $split_line[3]\n";
            }
            
            print HEAD "\n";

        }
    }

    # Printing tails
    print DATATABLE "\n|===\n";

    # Closing files
    close(SNAPSHOTS);
    close(DATATABLE);
    close(HEAD);
    close(TESTS);
}

sub create_output
{
    my ($opts) = @_;

    my $command = `cat temp/header.adoc > $$opts{outfile}.adoc`;
    $command = `cat temp/table.adoc >> $$opts{outfile}.adoc`;
    if ($$opts{link_pictures} == 0) { $command = `cat temp/snaps.adoc >> $$opts{outfile}.adoc`; }
    $command = `rm -R temp/`;
}