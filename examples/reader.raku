#!/usr/bin/env raku

my constant $root = $?FILE.IO.cleanup.parent.parent;
use lib $root.child('lib');

use Image::PNG::Portable;

sub MAIN(Str:D $file-path) {
    my $img = Image::PNG::Portable.new(:width(0), :height(0));
    
    $img.read($file-path)
        or die "Failed to read PNG file: $file-path";

    say "Image loaded: {$img.width}x{$img.height} pixels";

    for ^$img.height -> $y {
        my @row;
        for ^$img.width -> $x {
            my @px = $img.get($x, $y);
            push @row, $img.alpha ?? "({@px.join(',')})" !! "({@px[0..2].join(',')})";
        }
        say @row.join(' ');
    }
}
