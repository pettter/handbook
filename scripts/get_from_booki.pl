#!/usr/bin/perl

use warnings;
use strict;
use HTML::Parser;

my $book = `wget -O - http://booki.cc/cryptoparty-handbook`;

my @booklines = split "\n", $book;

print $booklines[0]."\n";

my $bookparser = new HTML::Parser(
		start_h => [\&book_start, "tagname, attr"],
		end_h   => [\&book_end, "tagname"],
		text_h  => [\&book_char, "text"]
	);

my $partparser = new HTML::Parser(
		start_h => [\&part_start, "tagname, attr, text"],
		end_h   => [\&part_end, "tagname, text"],
		text_h  => [\&part_char, "text"]
	);

#menu parsing globals
my $in_menu = 0;
my $current_chapter_num = -1;
my $current_chapter = "";
my $current_chapter_dir = "";
my $get_chapter = 0;

#part parsing globals
my $part_num = 0;
my $part_file = "";
my $part_path = "";
my $part_imgs = {};
my $part_img_num = 0;
my $found_content = 0;
my $result = "";
my $divs = 0;

sub part_start {
	my ($p, $attrs, $text) = @_;
	if ($p eq 'div') {
		if ($found_content == 0 and defined $attrs->{id} and $attrs->{id} eq "bookcontent"){
			$found_content = 1;
			$result = "";
			$divs=0;
			return;
		}
		if ($found_content == 1){
			$divs++;
		}
	}
	if($found_content == 1) {
		if( $p eq 'img' ){
			$part_imgs->{$attrs->{src}} = sprintf "%03d_%s", $part_img_num, "image"; 
			my $ending = $attrs->{src};
			$ending =~ s/.*(\.\w\w\w)$/\1/;
			$part_imgs->{$attrs->{src}} = $part_imgs->{$attrs->{src}}.$ending;
			if( $attrs->{src} =~ m/^http/ ){
				system("wget -O $current_chapter_dir/$part_imgs->{$attrs->{src}}  \"$attrs->{src}\"");
			}else{
				system("wget -O $current_chapter_dir/$part_imgs->{$attrs->{src}} \"http://booki.cc/$part_path/$attrs->{src}\"");
			}
			$text =~ s/$attrs->{src}/$part_imgs->{$attrs->{src}}/;
			$part_img_num++;
		}
		$result = $result.$text;
	}
	return;
}

sub part_char {
	my ($text) = @_;
	return unless $found_content == 1;
	$result = $result.$text;
}

sub part_end {
	my ($p, $text) = @_;
	return unless $found_content == 1;
	if ($p eq 'div') {
		$divs--;
	}
	$result = $result.$text;
	if ($divs == -1){
		$found_content = 0;
		open(OUT, ">".$current_chapter_dir."/".$part_file);
		print OUT $result;
		return;
	}
}

sub book_start {
	my ($p, $attrs) = @_;
	return unless $p =~ m/^(div|b|a)$/;
	if ($p eq 'div' and defined $attrs->{id} and $attrs->{id} eq 'bookmenu') {
		$in_menu = 1;
	}
	return unless $in_menu == 1;
	if ($p eq "b"){
		$get_chapter = 1;
		$current_chapter_num++;
		$part_num = 0;
		$part_img_num = 0;
	}
	if ($p eq "a"){
	    $part_path = $attrs->{href};
		$part_file = $part_path;
		$part_file =~ s/\/$//;
		$part_file =~ s/.*\///;
		$part_file =~ tr/-/_/;
		$part_file = sprintf "%02d_%s.html", $part_num, $part_file;
		$part_num++;
		my $part = `wget -O - http://booki.cc/$attrs->{href}`;
		$partparser->parse($part);
		my $part_md = $part_file;
		$part_md =~ s/\.html$/.md/;
		system("pandoc -f html -t markdown -o $current_chapter_dir/$part_md $current_chapter_dir/$part_file");
	}
};

sub book_end { 
	my ($p) = @_;
	if($p eq 'div' and $in_menu == 1){
		$in_menu = 0;
	}
	return;
};

sub book_char {
	my ($text) = @_;
	return unless $get_chapter == 1;
	$current_chapter = $text;
	$text =~ tr/[A-Z]/[a-z]/;
	$text =~ tr/ /_/;
	$current_chapter_dir = sprintf "chapter_%02d_%s", $current_chapter_num, $text;
	mkdir $current_chapter_dir;
	$get_chapter = 0;
};

$bookparser->parse($book);


