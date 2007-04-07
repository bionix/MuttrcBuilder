package Mutt::Config;

use 5.006;
use strict;
use warnings;

use Mutt::Config::Categories;
use Mutt::Config::Option;

our $VERSION = '0.01';

sub get_versions {
	my $self = shift;
	my $file = $INC{"Mutt/Config.pm"};

	return unless $file;

	$file =~ s(.pm$)(/Version/);

	return unless -e $file and -d $file;

	my @versions;
	opendir(my $dh, $file);
	while(my $version = readdir($dh)) {
		next unless $version =~ m#v([0-9_a-z-]+)\.pm#;
		$version = $1;
		$version =~ s/_/./g;
		push @versions, $version;
	}

	return @versions;
}

sub new {
	my ($class, $version) = @_;

	if ($version !~ m/^[0-9.a-z-]+/) {
		$@ = "Bad version: $version";
		return;
	}

	$version =~ s/[.-]/_/g;

	eval "use Mutt::Config::Version::v$version";
	if ($@) {
		$@ = "Unknown version: $version ($@)";
		return;
	}

	no strict "refs";
	my $self = {
		version        => $version,
	};

	my $variables_info;
	my $manual;
	{
		no strict "refs";
		$variables_info = ${ "Mutt::Config::Version::v"
	                      . $version . "::VARIABLES" };

		unless(${ "Mutt::Config::Version::v"
	                      . $version . "::MANUAL" }) {
			${ "Mutt::Config::Version::v"
                              . $version . "::MANUAL" } = join("", readline(
				*{ "Mutt::Config::Version::v"
					. $version . "::DATA" }
			));
		}

		$manual = \${ "Mutt::Config::Version::v"
                              . $version . "::MANUAL" };
	}

	my $variables;
	while(my($var, $info) = each %$variables_info) {
		$variables->{$var} = new Mutt::Config::Option(
			$var,
			$Mutt::Config::Categories::CATEGORIES{$var} ||"default",
			$info
		);
	}
	$self->{variables} = $variables;
	$self->{manual}    = $manual;

	return bless $self => $class;
}

sub get_categories {
	my ($self) = @_;
	my %seen;
	return grep { not $seen{$_}++ } values
		%Mutt::Config::Categories::CATEGORIES;
}

sub get_manual {
	my ($self) = @_;
	return ${ $self->{manual} };
}

sub get_variable {
	my ($self, $variable) = @_;
	return $self->{variables}->{$variable};
}

sub get_variables {
	my ($self, $page) = @_;

	return $self->{variables} unless $page;

	my %toreturn;
	while(my($name,$obj) = each(%{ $self->{variables} })) {
		$toreturn{$name} = $obj if ($obj->category eq $page);
	}
	return \%toreturn;
}

1;
