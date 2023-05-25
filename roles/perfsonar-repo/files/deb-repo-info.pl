#!/usr/bin/perl -w
###
# Script to collect and publish useful information about a Debian repository

use strict;
use Getopt::Long;
use Pod::Usage;
use Date::Format;

#
### ___ Initialisations ___ ###
#
my ($repo_path, $summary, $html, $verbose, $help, $man);
my ($repo_config, $current_distro);
my %distros;

# Get options or print short help if syntax error
GetOptions(
    'repo=s'    => \$repo_path,
    'summary'   => \$summary,
    'html'      => \$html,
    'verbose'   => \$verbose,
    'help|?'    => \$help,
    man         => \$man        ) or pod2usage(2);

# Call pod2usage if asked for help (see doc at __END__)
pod2usage(1) if $help;
pod2usage(-exitval => 0, -verbose => 2) if $man;

# Default values if not given
$repo_path = "/var/www/html/repository" unless $repo_path;
$repo_config = $repo_path."/conf/distributions";
$summary = 0 unless $summary;
$verbose = 0 unless $verbose;

#
### ___ Read the repository configuration file ___ ###
#
open(REPOCONFIG, "<", $repo_config) or die "Could not open < $repo_config";
while(<REPOCONFIG>) {
    if (/^Codename: ([^\s]+)$/) {
        $current_distro = $1;
        $distros{$current_distro}{name} = $1;
    }
    if (/^Suite: (.+)$/) {
        $distros{$current_distro}{suite} = $1;
    }
    if (/^Architectures: (.+)$/) {
        $distros{$current_distro}{archs} = $1;
    }
}
close REPOCONFIG;

#
### ___ Collect package information for each repository ___ ###
#
foreach my $distro (keys %distros) {
    foreach my $arch (split(' ', $distros{$distro}{archs})) {
        my $pkg;
        my $packages = $repo_path."/dists/".$distro."/main/";
        if ($arch eq "source") {
            $packages = "gzip -cd ".$packages.$arch."/Sources.gz |";
        } else {
            $packages .= "binary-".$arch."/Packages";
        }
        print "Reading ".$packages if $verbose;
        open(PACKAGES, $packages) or die "Could not open < $packages";;
        while(<PACKAGES>) {
            if (/^Package: ([^\s]+)$/) {
                $pkg = $1;
                $distros{$distro}{$arch}{packages}{$pkg}{name} = $1;
            }
            if (/^Version: ([^\s]+)$/) {
                $distros{$distro}{$arch}{packages}{$pkg}{version} = $1;
            }
        }
        close PACKAGES;
        printf(" - %d packages\n", scalar(keys %{$distros{$distro}{$arch}{packages}})) if $verbose;
    }
}

#
### ___ Publish information collected ___ ###
#
print "\n" if $verbose;

if ($html) {
    print  <<"END";
<HTML><HEAD>
<TITLE>Debian repository content</TITLE>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=utf-8" />
<STYLE TYPE="text/css">
h1 { text-align: center; font: bold 130% sans-serif; }
h2 { font: bold 115% sans-serif; margin-top: 2em; }
table { border: 2px solid gray; border-collapse: collapse; font-family: monospace; }
th { border: 1px solid black; padding: 2px; }
td { border: 1px solid black; padding: 2px; text-align: right; font-size: 90%; }
th.line { text-align: left; }
</STYLE>
</HEAD><BODY>
END
    print "<H1>Repository content on ".time2str("%a %b %e %Y at %T %Z (%z)", time)."</H1>\n";
    print "<UL>\n";
    foreach my $distro (sort {$a cmp $b} keys %distros) {
        print "<LI><A HREF=\"#$distro\">$distro</A>";
        if (exists($distros{$distro}{suite})) {
            print " — <A HREF=\"/debian/$distros{$distro}{suite}.list\">$distros{$distro}{suite}.list</A>";
        }
        print "</LI>\n";
    }
    foreach my $distro (sort {$a cmp $b} keys %distros) {
        my %all_packages;
        print "<H2 ID=\"$distro\">$distro — ";
        print "<A HREF=\"/debian/$distro.list\">$distro.list</A></H2>\n";
        print "<TABLE>\n<TR><TH>&nbsp;</TH>";
        foreach my $arch (split(' ', $distros{$distro}{archs})) {
            @all_packages{ keys %{$distros{$distro}{$arch}{packages}} } = values %{$distros{$distro}{$arch}{packages}};
            # A header for each architecture
            printf("<TH>%s (%s)</TH>", $arch, scalar(keys %{$distros{$distro}{$arch}{packages}}));
        }
        print "</TR>\n";
        foreach my $pkg (sort keys %{all_packages}) {
            print "<TR><TH class=\"line\">$all_packages{$pkg}{name}</TH>\n";
            foreach my $arch (split(' ', $distros{$distro}{archs})) {
                my $version = "-";
                if (exists($distros{$distro}{$arch}{packages}{$pkg})) {
                    $version = $distros{$distro}{$arch}{packages}{$pkg}{version};
                }
                printf("<TD>%s</TD>\n", $version);
            }
            print "</TR>\n";
        }
        print "</TABLE>\n";
    }
    print "</BODY></HTML>\n";
} else {
    print "\x1b[1mRepository content:\x1b[0m\n";
    print time2str("Generated on %a %b %e %Y at %T %Z (%z)\n", time);
    foreach my $distro (sort {$a cmp $b} keys %distros) {
        printf("\n\x1b[4m%s:\x1b[0m\n", $distro);
        foreach my $arch (split(' ', $distros{$distro}{archs})) {
            printf("\x1b[1m%s\x1b[0m - %d packages\n", $arch, scalar(keys %{$distros{$distro}{$arch}{packages}}));
            if (!$summary) {
                foreach my $pkg (sort keys %{$distros{$distro}{$arch}{packages}}) {
                    printf("\t\x1b[1m%s\x1b[0m - %s\n",
                        $distros{$distro}{$arch}{packages}{$pkg}{name},
                        $distros{$distro}{$arch}{packages}{$pkg}{version}
                    )
                }
            }
        }
    }
}

__END__

=encoding utf-8

=head1 deb-repo-info.pl

Script to collects and prints informations about the local Debian repositories

=head1 SYNOPSIS

deb-repo-info.pl [options]

 Options:
   -repo        repository location (main directory)
   -summary     reports summary information only
   -html        render output in HTML
   -verbose     verbose mode
   -help        brief help message
   -man         full documentation

=head1 OPTIONS

=over

=item B<-repo dir>

Root directory of the Debian repositories.  If not given, defaults to /var/www/html/repository

This directory should contain the usual Debian repository directories: conf, db, dists and pool.

=item B<-summary>

Reports summary information only:
  - repository names
  - architectures
  - number of packages

=item B<-html>

Enables rendering the output of the script in HTML to be shown in a web browser.

=item B<-verbose>

Enables verbose output when running the script.

=item B<-help>

Prints a brief help message and exits.

=item B<-man>

Prints the manual page and exits.

=back

=head1 DESCRIPTION

This script collect information about Debian repositories stored on the local host.  A summary of this information is then output to the user.

The information it collects is the following:
  - the name of the repositories
  - the architectures of packages present in each repository
  - the number of packages in each distro (aka a repo and an arch)

All architectures are considered, both binaries and source.

=head1 TODO

We should add the following functionnality:
  - output in JSON for machine consumption
  - check that we have the same number of packages in each distro (except for source)
  - distro consistency check: check that the version of a package is the same for all architectures inside any given repository
  - check that all binary packages of a source package are present in the repository
  - check that the version of packages inside the -snapshot repository is higher than the one in the -release repository

=head1 AUTHOR

Antoine Delvaux (GÉANT).

=cut

